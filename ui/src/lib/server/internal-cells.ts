import postgres from 'postgres';
import { Effect, Match, Redacted, Schema } from 'effect';
import { Config } from './services/Config';
import type { TextPartContent, ToolCallPartContent, ToolResultPartContent } from './db/schema';

const encoder = new TextEncoder();

const base64UrlEncode = (value: Uint8Array): string =>
  btoa(String.fromCharCode(...value))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');

const constantTimeEqual = (left: Uint8Array, right: Uint8Array): boolean => {
  if (left.byteLength !== right.byteLength) return false;
  let difference = 0;
  for (let index = 0; index < left.byteLength; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
};

const constantTimeEqualStrings = (left: string, right: string): boolean =>
  constantTimeEqual(encoder.encode(left), encoder.encode(right));

const sha256 = (value: string): Effect.Effect<Uint8Array> =>
  Effect.promise(() =>
    crypto.subtle.digest('SHA-256', encoder.encode(value)).then((digest) => new Uint8Array(digest)),
  );

const hmacSha256 = (secret: string, message: string): Effect.Effect<Uint8Array> =>
  Effect.promise(() =>
    crypto.subtle
      .importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
      .then((key) =>
        crypto.subtle
          .sign('HMAC', key, encoder.encode(message))
          .then((signature) => new Uint8Array(signature)),
      ),
  );

export const internalSignature = (
  secret: string,
  method: string,
  pathname: string,
  body: string,
  timestamp: string,
): Effect.Effect<string> =>
  Effect.gen(function* () {
    const digest = yield* sha256(body);
    const signature = yield* hmacSha256(
      secret,
      `${timestamp}\n${method}\n${pathname}\n${base64UrlEncode(digest)}`,
    );
    return base64UrlEncode(signature);
  });

const MAX_CLOCK_SKEW_MS = 30_000;

export class InternalCellError extends Schema.TaggedError<InternalCellError>()(
  'InternalCellError',
  {
    status: Schema.Number,
    message: Schema.String,
  },
) {}

const ProjectionMessage = Schema.Struct({
  id: Schema.String,
  role: Schema.Literal('user', 'assistant', 'tool'),
  content: Schema.String,
  createdAt: Schema.Number,
  toolCallId: Schema.optional(Schema.String),
  toolName: Schema.optional(Schema.String),
  toolArguments: Schema.optional(Schema.Unknown),
  toolResult: Schema.optional(Schema.Unknown),
  toolFailed: Schema.optional(Schema.Boolean),
});

export const ProjectedChatSnapshot = Schema.Struct({
  id: Schema.String,
  userId: Schema.String,
  dataset: Schema.String,
  title: Schema.String,
  deleted: Schema.Boolean,
  generating: Schema.Boolean,
  currentMessageRequestId: Schema.NullOr(Schema.String),
  createdAt: Schema.Number,
  updatedAt: Schema.Number,
  messages: Schema.Array(ProjectionMessage),
});
export type ProjectedChatSnapshot = typeof ProjectedChatSnapshot.Type;

export const ProjectionEvent = Schema.Struct({
  sequence: Schema.Number.pipe(Schema.int(), Schema.positive()),
  type: Schema.Literal('chat-snapshot'),
  occurredAt: Schema.Number,
  snapshot: ProjectedChatSnapshot,
});
export type ProjectionEvent = typeof ProjectionEvent.Type;

export const ProjectionRequest = Schema.Struct({
  cellKind: Schema.Literal('chat'),
  cellId: Schema.String,
  events: Schema.Array(ProjectionEvent).pipe(Schema.minItems(1), Schema.maxItems(100)),
});
export type ProjectionRequest = typeof ProjectionRequest.Type;

export const verifyInternalCellRequest = (request: Request, body: string) =>
  Effect.gen(function* () {
    const config = yield* Config;
    const timestamp = request.headers.get('x-datalk-internal-timestamp');
    const signature = request.headers.get('x-datalk-internal-signature');
    if (!timestamp || !signature) {
      return yield* Effect.fail(
        new InternalCellError({ status: 401, message: 'Missing internal signature' }),
      );
    }
    const issuedAt = Number(timestamp);
    if (!Number.isSafeInteger(issuedAt) || Math.abs(Date.now() - issuedAt) > MAX_CLOCK_SKEW_MS) {
      return yield* Effect.fail(
        new InternalCellError({ status: 401, message: 'Expired internal signature' }),
      );
    }
    const expected = yield* internalSignature(
      Redacted.value(config.internalProjectionSecret),
      request.method,
      new URL(request.url).pathname,
      body,
      timestamp,
    );
    if (!constantTimeEqualStrings(signature, expected)) {
      return yield* Effect.fail(
        new InternalCellError({ status: 401, message: 'Invalid internal signature' }),
      );
    }
  });

const withSql = <A>(run: (sql: postgres.Sql) => Promise<A>) =>
  Effect.gen(function* () {
    const config = yield* Config;
    const sql = postgres(Redacted.value(config.databaseUrl), { max: 1 });
    return yield* Effect.acquireUseRelease(
      Effect.succeed(sql),
      (client) =>
        Effect.tryPromise({
          try: () => run(client),
          catch: (cause) =>
            cause instanceof InternalCellError
              ? cause
              : new InternalCellError({
                  status: 500,
                  message: `PostgreSQL operation failed: ${String(cause)}`,
                }),
        }),
      (client) => Effect.promise(() => client.end()),
    );
  });

const applySnapshot = async (sql: postgres.TransactionSql, snapshot: ProjectedChatSnapshot) => {
  const updatedAt = new Date(snapshot.updatedAt);
  const createdAt = new Date(snapshot.createdAt);
  await sql`
    INSERT INTO chat (id, user_id, dataset, created_at, updated_at, "currentMessageRequest", title, deleted_at)
    VALUES (${snapshot.id}::uuid, ${snapshot.userId}, ${snapshot.dataset}, ${createdAt}, ${updatedAt}, ${snapshot.currentMessageRequestId}::uuid, ${snapshot.title}, ${snapshot.deleted ? updatedAt : null})
    ON CONFLICT (id) DO UPDATE SET
      user_id = EXCLUDED.user_id,
      dataset = EXCLUDED.dataset,
      updated_at = EXCLUDED.updated_at,
      "currentMessageRequest" = EXCLUDED."currentMessageRequest",
      title = EXCLUDED.title,
      deleted_at = EXCLUDED.deleted_at
  `;
  await sql`DELETE FROM chat_message WHERE chat_id = ${snapshot.id}::uuid`;
  for (const [sequence, message] of snapshot.messages.entries()) {
    const [stored] = await sql`
      INSERT INTO chat_message (chat_id, role, sequence, created_at)
      VALUES (${snapshot.id}::uuid, ${message.role}, ${sequence}, ${new Date(message.createdAt)})
      RETURNING id
    `;
    const parts = Match.value(message.role).pipe(
      Match.when(
        'tool',
        (): ReadonlyArray<{ type: string; sequence: number; content: postgres.JSONValue }> => {
          if (!message.toolCallId || !message.toolName) {
            throw new InternalCellError({
              status: 400,
              message: 'Tool message is missing toolCallId or toolName',
            });
          }
          const parts: Array<{ type: string; sequence: number; content: postgres.JSONValue }> = [
            {
              type: 'tool-call',
              sequence: 0,
              content: {
                id: message.toolCallId,
                name: message.toolName,
                params: message.toolArguments,
              } satisfies ToolCallPartContent as postgres.JSONValue,
            },
          ];
          if (message.toolResult !== undefined) {
            parts.push({
              type: 'tool-result',
              sequence: 1,
              content: {
                id: message.toolCallId,
                name: message.toolName,
                result: message.toolResult,
                isFailure: message.toolFailed ?? false,
              } satisfies ToolResultPartContent as postgres.JSONValue,
            });
          }
          return parts;
        },
      ),
      Match.orElse(
        (): ReadonlyArray<{ type: string; sequence: number; content: postgres.JSONValue }> => [
          {
            type: 'text',
            sequence: 0,
            content: { text: message.content } satisfies TextPartContent,
          },
        ],
      ),
    );
    for (const part of parts) {
      await sql`
        INSERT INTO chat_message_part (message_id, type, sequence, content)
        VALUES (${stored.id}, ${part.type}, ${part.sequence}, ${sql.json(part.content)})
      `;
    }
  }
};

export const projectCellEvents = (request: ProjectionRequest) =>
  withSql(async (sql) =>
    sql.begin(async (transaction) => {
      const events = [...request.events].sort((left, right) => left.sequence - right.sequence);
      if (
        events.some(
          (event, index) => index > 0 && event.sequence !== events[index - 1].sequence + 1,
        )
      ) {
        throw new InternalCellError({
          status: 400,
          message: 'Projection batch must be contiguous',
        });
      }
      const initialSequence = events[0].sequence - 1;
      await transaction`
        INSERT INTO cell_projection_ledger (cell_kind, cell_id, last_sequence)
        VALUES (${request.cellKind}, ${request.cellId}, ${initialSequence})
        ON CONFLICT (cell_kind, cell_id) DO NOTHING
      `;
      const [ledger] = await transaction`
        SELECT last_sequence FROM cell_projection_ledger
        WHERE cell_kind = ${request.cellKind} AND cell_id = ${request.cellId}
        FOR UPDATE
      `;
      const lastSequence = Number(ledger.last_sequence);
      const pending = events.filter((event) => event.sequence > lastSequence);
      if (pending.length === 0) return { acknowledgedSequence: lastSequence };
      if (pending[0].sequence !== lastSequence + 1) {
        throw new InternalCellError({ status: 409, message: 'Projection sequence gap' });
      }
      for (const event of pending) await applySnapshot(transaction, event.snapshot);
      const acknowledgedSequence = pending.at(-1)!.sequence;
      await transaction`
        UPDATE cell_projection_ledger
        SET last_sequence = ${acknowledgedSequence}, updated_at = now()
        WHERE cell_kind = ${request.cellKind} AND cell_id = ${request.cellId}
      `;
      return { acknowledgedSequence };
    }),
  );

export const hydrateUser = (userId: string) =>
  withSql(
    async (sql) =>
      sql`
      SELECT id, dataset, COALESCE(title, '...') AS title, EXTRACT(EPOCH FROM updated_at) * 1000 AS "updatedAt",
        ("currentMessageRequest" IS NOT NULL) AS generating
      FROM chat
      WHERE user_id = ${userId} AND deleted_at IS NULL
      ORDER BY updated_at DESC
    `,
  );

export const hydrateChat = (chatId: string, userId: string) =>
  withSql(async (sql) => {
    const [chat] = await sql`
      SELECT id, user_id AS "userId", dataset, COALESCE(title, '...') AS title, "currentMessageRequest" AS "currentMessageRequestId",
        EXTRACT(EPOCH FROM created_at) * 1000 AS "createdAt", EXTRACT(EPOCH FROM updated_at) * 1000 AS "updatedAt"
      FROM chat WHERE id = ${chatId}::uuid AND user_id = ${userId} AND deleted_at IS NULL
    `;
    if (!chat) return null;
    const messages = await sql`
      SELECT m.id, m.role, EXTRACT(EPOCH FROM m.created_at) * 1000 AS "createdAt", p.type, p.content
      FROM chat_message m JOIN chat_message_part p ON p.message_id = m.id
      WHERE m.chat_id = ${chatId}::uuid
      ORDER BY m.sequence, p.sequence
    `;
    return {
      id: chat.id,
      userId: chat.userId,
      dataset: chat.dataset,
      title: chat.title,
      deleted: false,
      generating: chat.currentMessageRequestId !== null,
      currentMessageRequestId: chat.currentMessageRequestId,
      createdAt: Number(chat.createdAt),
      updatedAt: Number(chat.updatedAt),
      messages: messages.map((message) => ({
        id: String(message.id),
        role: message.type === 'tool-call' ? 'tool' : message.role,
        content: message.type === 'text' ? message.content.text : '',
        createdAt: Number(message.createdAt),
        ...(message.type === 'tool-call'
          ? {
              toolCallId: message.content.id,
              toolName: message.content.name,
              toolArguments: message.content.params,
            }
          : {}),
      })),
    };
  });
