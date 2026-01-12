import { Effect, Layer, Option, Duration, Scope, Context, Schema } from 'effect';
import { Persistence } from '@effect/experimental';
import { eq, asc, count } from 'drizzle-orm';
import { Database } from './Database';
import * as T from '$lib/server/db/schema';

// ============================================================================
// Schemas for @effect/ai Prompt format (used for parsing and validation)
// ============================================================================

const TextPartEncodedSchema = Schema.Struct({
  type: Schema.Literal('text'),
  text: Schema.String,
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const ToolCallPartEncodedSchema = Schema.Struct({
  type: Schema.Literal('tool-call'),
  id: Schema.String,
  name: Schema.String,
  params: Schema.Unknown,
  providerExecuted: Schema.optional(Schema.Boolean),
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const ToolResultPartEncodedSchema = Schema.Struct({
  type: Schema.Literal('tool-result'),
  id: Schema.String,
  name: Schema.String,
  isFailure: Schema.Boolean,
  result: Schema.Unknown,
  providerExecuted: Schema.optional(Schema.Boolean),
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const ReasoningPartEncodedSchema = Schema.Struct({
  type: Schema.Literal('reasoning'),
  text: Schema.String,
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const FilePartEncodedSchema = Schema.Struct({
  type: Schema.Literal('file'),
  mediaType: Schema.String,
  url: Schema.optional(Schema.String),
  data: Schema.optional(Schema.String),
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const PartEncodedSchema = Schema.Union(
  TextPartEncodedSchema,
  ToolCallPartEncodedSchema,
  ToolResultPartEncodedSchema,
  ReasoningPartEncodedSchema,
  FilePartEncodedSchema,
);

const MessageEncodedSchema = Schema.Struct({
  role: Schema.Literal('system', 'user', 'assistant', 'tool'),
  content: Schema.Union(Schema.String, Schema.Array(PartEncodedSchema)),
  options: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

const PromptEncodedSchema = Schema.Struct({
  content: Schema.Array(MessageEncodedSchema),
});

// ============================================================================
// Types for @effect/ai Prompt format (derived from schemas)
// ============================================================================

type PromptEncoded = typeof PromptEncodedSchema.Type;
type MessageEncoded = typeof MessageEncodedSchema.Type;
type PartEncoded = typeof PartEncodedSchema.Type;
type TextPartEncoded = typeof TextPartEncodedSchema.Type;
type ToolCallPartEncoded = typeof ToolCallPartEncodedSchema.Type;
type ToolResultPartEncoded = typeof ToolResultPartEncodedSchema.Type;
type ReasoningPartEncoded = typeof ReasoningPartEncodedSchema.Type;
type FilePartEncoded = typeof FilePartEncodedSchema.Type;

// ============================================================================
// BackingPersistence Implementation
// ============================================================================

/**
 * Creates a BackingPersistenceStore for a given storeId.
 * This implements the key-value interface required by @effect/ai Chat.Persisted.
 * Uses normalized tables for storage.
 */
const makeStore = (
  storeId: string,
  db: Context.Tag.Service<typeof Database>,
): Effect.Effect<Persistence.BackingPersistenceStore, never, Scope.Scope> =>
  Effect.gen(function* () {
    yield* Effect.addFinalizer(() => Effect.void);

    /**
     * Get chat history by reconstructing the Prompt format from normalized tables
     */
    const get = (
      key: string,
    ): Effect.Effect<Option.Option<unknown>, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logDebug(`[ChatPersistence.get] Getting history for ${key}`);

        const messages = yield* db.query.chatMessage
          .findMany({
            where: eq(T.chatMessage.chatId, key),
            orderBy: [asc(T.chatMessage.sequence)],
            with: {
              parts: {
                orderBy: [asc(T.chatMessagePart.sequence)],
              },
            },
          })
          .pipe(
            Effect.mapError(
              (error) =>
                new Persistence.PersistenceBackingError({
                  reason: 'BackingError',
                  method: 'get',
                  cause: error,
                }),
            ),
          );

        if (messages.length === 0) {
          yield* Effect.logDebug(`[ChatPersistence.get] No messages found`);
          return Option.none();
        }

        // Reconstruct the Prompt format
        const prompt: PromptEncoded = {
          content: messages.map((msg) => {
            // System messages have string content
            if (msg.role === 'system') {
              const textPart = msg.parts.find((p) => p.type === 'text');
              return {
                role: msg.role,
                content: textPart ? (textPart.content as T.TextPartContent).text : '',
              } as MessageEncoded;
            }

            // Other messages have array content
            const parts: PartEncoded[] = msg.parts.map((part) => {
              switch (part.type) {
                case 'text': {
                  const content = part.content as T.TextPartContent;
                  return { type: 'text', text: content.text } as TextPartEncoded;
                }
                case 'tool-call': {
                  const content = part.content as T.ToolCallPartContent;
                  return {
                    type: 'tool-call',
                    id: content.id,
                    name: content.name,
                    params: content.params,
                    providerExecuted: content.providerExecuted ?? false,
                  } as ToolCallPartEncoded;
                }
                case 'tool-result': {
                  const content = part.content as T.ToolResultPartContent;
                  return {
                    type: 'tool-result',
                    id: content.id,
                    name: content.name,
                    result: content.result,
                    isFailure: content.isFailure,
                    providerExecuted: content.providerExecuted ?? false,
                  } as ToolResultPartEncoded;
                }
                case 'reasoning': {
                  const content = part.content as T.ReasoningPartContent;
                  return { type: 'reasoning', text: content.text } as ReasoningPartEncoded;
                }
                case 'file': {
                  const content = part.content as T.FilePartContent;
                  return {
                    type: 'file',
                    mediaType: content.mediaType,
                    url: content.url,
                    data: content.data,
                  } as FilePartEncoded;
                }
                default:
                  return { type: 'text', text: '' } as TextPartEncoded;
              }
            });

            return {
              role: msg.role,
              content: parts,
            } as MessageEncoded;
          }),
        };

        yield* Effect.logDebug(`[ChatPersistence.get] Reconstructed ${messages.length} messages`);
        // Return as JSON string - @effect/ai expects this format
        return Option.some(JSON.stringify(prompt));
      });

    const getMany = (
      keys: Array<string>,
    ): Effect.Effect<Array<Option.Option<unknown>>, Persistence.PersistenceError> =>
      Effect.all(keys.map(get), { concurrency: 'inherit' });

    /**
     * Save chat history by parsing the Prompt and storing in normalized tables
     */
    const set = (
      key: string,
      value: unknown,
      _ttl: Option.Option<Duration.Duration>,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logDebug(`[ChatPersistence.set] Saving history for ${key}`);

        // Parse and validate the prompt using Effect Schema
        const promptJson = typeof value === 'string' ? value : JSON.stringify(value);
        const parseResult = yield* Schema.decodeUnknown(Schema.parseJson(PromptEncodedSchema))(
          promptJson,
        ).pipe(
          Effect.mapError(
            (parseError) =>
              new Persistence.PersistenceBackingError({
                reason: 'BackingError',
                method: 'set',
                cause: parseError,
              }),
          ),
        );
        const prompt = parseResult;

        // Get count of existing messages to only insert new ones (append-only optimization)
        // @effect/ai history is append-only, so we don't need to update existing messages
        const [{ existingCount }] = yield* db
          .select({ existingCount: count() })
          .from(T.chatMessage)
          .where(eq(T.chatMessage.chatId, key))
          .pipe(
            Effect.mapError(
              (error) =>
                new Persistence.PersistenceBackingError({
                  reason: 'BackingError',
                  method: 'set',
                  cause: error,
                }),
            ),
          );

        // Build batch insert data for messages and parts
        const messagesToInsert = [];
        const partsToInsert = [];

        // Only process messages that are new (sequence >= existingCount)
        for (let msgIdx = existingCount; msgIdx < prompt.content.length; msgIdx++) {
          const msg = prompt.content[msgIdx];
          messagesToInsert.push({
            chatId: key,
            role: msg.role,
            sequence: msgIdx,
          });

          // Process parts for this message
          const parts =
            typeof msg.content === 'string'
              ? [{ type: 'text' as const, text: msg.content }]
              : msg.content;

          for (let partIdx = 0; partIdx < parts.length; partIdx++) {
            const part = parts[partIdx];
            let partType: 'text' | 'tool-call' | 'tool-result' | 'file' | 'reasoning';
            let content: T.MessagePartContent;

            switch (part.type) {
              case 'text':
                partType = 'text';
                content = { text: part.text };
                break;
              case 'tool-call':
                partType = 'tool-call';
                content = {
                  id: part.id,
                  name: part.name,
                  params: part.params,
                  providerExecuted: part.providerExecuted,
                };
                break;
              case 'tool-result':
                partType = 'tool-result';
                content = {
                  id: part.id,
                  name: part.name,
                  result: part.result,
                  isFailure: part.isFailure,
                  providerExecuted: part.providerExecuted,
                };
                break;
              case 'reasoning':
                partType = 'reasoning';
                content = { text: part.text };
                break;
              case 'file':
                partType = 'file';
                content = {
                  mediaType: part.mediaType,
                  url: part.url,
                  data: part.data,
                };
                break;
              default:
                continue;
            }

            partsToInsert.push({
              messageSequence: msgIdx,
              type: partType,
              sequence: partIdx,
              content,
            });
          }
        }

        // Batch insert messages and get their IDs
        let newMessagesInserted = 0;
        if (messagesToInsert.length > 0) {
          const insertedMessages = yield* db
            .insert(T.chatMessage)
            .values(messagesToInsert)
            .returning({ id: T.chatMessage.id, sequence: T.chatMessage.sequence })
            .pipe(
              Effect.mapError(
                (error) =>
                  new Persistence.PersistenceBackingError({
                    reason: 'BackingError',
                    method: 'set',
                    cause: error,
                  }),
              ),
            );

          // Build a map of sequence -> message id for inserting parts
          const messageIdMap = new Map(insertedMessages.map(({ id, sequence }) => [sequence, id]));

          // Batch insert all parts at once
          if (partsToInsert.length > 0) {
            yield* db
              .insert(T.chatMessagePart)
              .values(
                partsToInsert.map(({ messageSequence, type, sequence, content }) => ({
                  messageId: messageIdMap.get(messageSequence)!,
                  type,
                  sequence,
                  content,
                })),
              )
              .pipe(
                Effect.mapError(
                  (error) =>
                    new Persistence.PersistenceBackingError({
                      reason: 'BackingError',
                      method: 'set',
                      cause: error,
                    }),
                ),
              );
          }

          newMessagesInserted = messagesToInsert.length;
        }

        yield* Effect.logDebug(
          `[ChatPersistence.set] Saved ${newMessagesInserted} new messages (total: ${prompt.content.length})`,
        );
      });

    const setMany = (
      entries: ReadonlyArray<
        readonly [key: string, value: unknown, ttl: Option.Option<Duration.Duration>]
      >,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.all(
        entries.map(([key, value, ttl]) => set(key, value, ttl)),
        { concurrency: 'inherit', discard: true },
      );

    const remove = (key: string): Effect.Effect<void, Persistence.PersistenceError> =>
      db
        .delete(T.chatMessage)
        .where(eq(T.chatMessage.chatId, key))
        .pipe(
          Effect.mapError(
            (error) =>
              new Persistence.PersistenceBackingError({
                reason: 'BackingError',
                method: 'remove',
                cause: error,
              }),
          ),
        );

    // No-op: we don't filter by storeId since we use normalized tables
    // If needed in the future, add a storeId column to chatMessage
    const clear: Effect.Effect<void, Persistence.PersistenceError> = Effect.void;

    return {
      get,
      getMany,
      set,
      setMany,
      remove,
      clear,
    };
  });

// ============================================================================
// BackingPersistence Service
// ============================================================================

/**
 * BackingPersistence implementation using PostgreSQL with normalized tables.
 * This is used by @effect/ai Chat.Persisted to store conversation history.
 */
export const ChatBackingPersistenceLive = Layer.effect(
  Persistence.BackingPersistence,
  Effect.gen(function* () {
    const db = yield* Database;

    return {
      [Persistence.BackingPersistenceTypeId]: Persistence.BackingPersistenceTypeId,
      make: (storeId: string) => makeStore(storeId, db),
    } as Persistence.BackingPersistence;
  }),
);
