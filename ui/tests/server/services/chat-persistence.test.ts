import { describe, expect, it } from 'vitest';
import { Effect, Exit, Layer, Option } from 'effect';
import { Persistence } from '@effect/experimental';
import { ChatBackingPersistenceLive } from '$lib/server/services/ChatPersistence';
import { Database } from '$lib/server/services/Database';

const applyOps = <T>(
  value: Effect.Effect<T>,
  ops: Array<(effect: Effect.Effect<T>) => Effect.Effect<T>>,
) => ops.reduce((effect, op) => op(effect), value);

const createFakeDatabase = () => {
  const messages: Array<{
    id: string;
    chatId: string;
    role: string;
    sequence: number;
  }> = [];
  const parts: Array<{
    messageId: string;
    type: string;
    sequence: number;
    content: unknown;
  }> = [];

  const select = () => ({
    from: () => ({
      where: () => ({
        pipe: (
          ...ops: Array<
            (effect: Effect.Effect<{ existingCount: number }[]>) => Effect.Effect<
              {
                existingCount: number;
              }[]
            >
          >
        ) => applyOps(Effect.succeed([{ existingCount: messages.length }]), ops),
      }),
    }),
  });

  const insert = () => ({
    values: (rows: Array<Record<string, unknown>>) => {
      const isMessageInsert = rows.length > 0 && 'chatId' in rows[0];
      if (isMessageInsert) {
        rows.forEach((row, index) => {
          messages.push({
            id: `msg-${messages.length + index + 1}`,
            chatId: row.chatId as string,
            role: row.role as string,
            sequence: row.sequence as number,
          });
        });
      } else {
        rows.forEach((row) => {
          parts.push({
            messageId: row.messageId as string,
            type: row.type as string,
            sequence: row.sequence as number,
            content: row.content,
          });
        });
      }

      return {
        returning: () => ({
          pipe: (
            ...ops: Array<
              (effect: Effect.Effect<{ id: string; sequence: number }[]>) => Effect.Effect<
                {
                  id: string;
                  sequence: number;
                }[]
              >
            >
          ) =>
            applyOps(
              Effect.succeed(
                messages.slice(-rows.length).map((message) => ({
                  id: message.id,
                  sequence: message.sequence,
                })),
              ),
              ops,
            ),
        }),
        pipe: (...ops: Array<(effect: Effect.Effect<void>) => Effect.Effect<void>>) =>
          applyOps(Effect.succeed(undefined), ops),
      };
    },
  });

  const query = {
    chatMessage: {
      findMany: () =>
        Effect.succeed(
          messages.map((message) => ({
            ...message,
            parts: parts
              .filter((part) => part.messageId === message.id)
              .sort((a, b) => a.sequence - b.sequence),
          })),
        ),
    },
  };

  const remove = () => ({
    where: () => ({
      pipe: (...ops: Array<(effect: Effect.Effect<void>) => Effect.Effect<void>>) =>
        applyOps(Effect.succeed(undefined), ops),
    }),
  });

  const db = {
    query,
    select,
    insert,
    delete: remove,
  } as const;

  return { db, messages, parts };
};

describe('ChatPersistence backing store', () => {
  it('stores and reconstructs prompt history', async () => {
    const { db, messages, parts } = createFakeDatabase();

    const layer = Layer.provide(ChatBackingPersistenceLive, Layer.succeed(Database, db as never));

    const store = await Effect.runPromise(
      Effect.scoped(
        Effect.gen(function* () {
          const backing = yield* Persistence.BackingPersistence;
          return yield* backing.make('store-id');
        }).pipe(Effect.provide(layer)),
      ),
    );

    const inputPrompt = {
      content: [
        { role: 'user', content: 'Hello' },
        { role: 'assistant', content: [{ type: 'text', text: 'Hi there' }] },
      ],
    };

    const expectedPrompt = {
      content: [
        { role: 'user', content: [{ type: 'text', text: 'Hello' }] },
        { role: 'assistant', content: [{ type: 'text', text: 'Hi there' }] },
      ],
    };

    await Effect.runPromise(
      store.set('chat-1', JSON.stringify(inputPrompt), Option.none()).pipe(Effect.provide(layer)),
    );

    const result = await Effect.runPromise(store.get('chat-1').pipe(Effect.provide(layer)));

    expect(Option.isSome(result)).toBe(true);

    if (Option.isSome(result)) {
      expect(JSON.parse(result.value as string)).toEqual(expectedPrompt);
    }

    expect(messages.length).toBe(2);
    expect(parts.length).toBe(2);
  });

  it('stores only new messages on repeated saves', async () => {
    const { db, messages, parts } = createFakeDatabase();

    const layer = Layer.provide(ChatBackingPersistenceLive, Layer.succeed(Database, db as never));

    const store = await Effect.runPromise(
      Effect.scoped(
        Effect.gen(function* () {
          const backing = yield* Persistence.BackingPersistence;
          return yield* backing.make('store-id');
        }).pipe(Effect.provide(layer)),
      ),
    );

    const prompt = {
      content: [
        { role: 'user', content: 'One' },
        { role: 'assistant', content: [{ type: 'text', text: 'Two' }] },
        { role: 'user', content: 'Three' },
      ],
    };

    await Effect.runPromise(
      store.set('chat-1', JSON.stringify(prompt), Option.none()).pipe(Effect.provide(layer)),
    );

    await Effect.runPromise(
      store.set('chat-1', JSON.stringify(prompt), Option.none()).pipe(Effect.provide(layer)),
    );

    expect(messages.length).toBe(3);
    expect(parts.length).toBe(3);
  });

  it('fails when prompt schema is invalid', async () => {
    const { db } = createFakeDatabase();

    const layer = Layer.provide(ChatBackingPersistenceLive, Layer.succeed(Database, db as never));

    const store = await Effect.runPromise(
      Effect.scoped(
        Effect.gen(function* () {
          const backing = yield* Persistence.BackingPersistence;
          return yield* backing.make('store-id');
        }).pipe(Effect.provide(layer)),
      ),
    );

    const exit = await Effect.runPromiseExit(
      store
        .set('chat-1', JSON.stringify({ wrong: true }), Option.none())
        .pipe(Effect.provide(layer)),
    );

    expect(Exit.isFailure(exit)).toBe(true);
  });
});
