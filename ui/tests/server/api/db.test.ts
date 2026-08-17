import { describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option } from 'effect';
import { getChatWithHistory, getChatsForUser } from '$lib/server/api/db';
import { Database } from '$lib/server/services/Database';
import { DatabaseError } from '$lib/server/errors';

const makeLayer = (db: unknown) => Layer.succeed(Database, db as never);

describe('db api helpers', () => {
  it('returns none when chat is missing', async () => {
    const db = {
      query: {
        chat: {
          findFirst: () => Effect.succeed(null),
        },
      },
    };

    const result = await Effect.runPromise(
      getChatWithHistory('user-1', 'chat-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Option.isNone(result)).toBe(true);
  });

  it('returns empty messages when chat has no history', async () => {
    const db = {
      query: {
        chat: {
          findFirst: () =>
            Effect.succeed({
              id: 'chat-1',
              userId: 'user-1',
              currentMessageRequest: 'req-1',
              currentMessageRequestRecord: { content: 'pending' },
              messages: [],
            }),
        },
      },
    };

    const result = await Effect.runPromise(
      getChatWithHistory('user-1', 'chat-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Option.isSome(result)).toBe(true);

    if (Option.isSome(result)) {
      expect(result.value.currentMessageRequest).toBe('req-1');
      expect(result.value.currentMessageRequestContent).toBe('pending');
      expect(result.value.messages).toEqual([]);
    }
  });

  it('maps chat history parts to display messages', async () => {
    const db = {
      query: {
        chat: {
          findFirst: () =>
            Effect.succeed({
              id: 'chat-1',
              userId: 'user-1',
              currentMessageRequest: null,
              currentMessageRequestRecord: null,
              messages: [
                {
                  role: 'user',
                  sequence: 0,
                  parts: [
                    { type: 'text', sequence: 0, content: { text: 'Hello' } },
                    {
                      type: 'tool-call',
                      sequence: 1,
                      content: { id: 'tool-1', name: 'run_sql', params: { q: 1 } },
                    },
                  ],
                },
                {
                  role: 'assistant',
                  sequence: 1,
                  parts: [
                    {
                      type: 'tool-result',
                      sequence: 0,
                      content: {
                        id: 'tool-1',
                        name: 'run_sql',
                        result: { ok: true },
                        isFailure: false,
                      },
                    },
                    { type: 'text', sequence: 1, content: { text: 'Done' } },
                  ],
                },
              ],
            }),
        },
      },
    };

    const result = await Effect.runPromise(
      getChatWithHistory('user-1', 'chat-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Option.isSome(result)).toBe(true);

    if (Option.isSome(result)) {
      expect(result.value.messages).toEqual([
        { role: 'user', content: 'Hello' },
        {
          role: 'tool',
          name: 'run_sql',
          arguments: JSON.stringify({ q: 1 }),
          output: { ok: true },
          toolCallId: 'tool-1',
        },
        { role: 'assistant', content: 'Done' },
      ]);
    }
  });

  it('loads chats for a user', async () => {
    const orderBy = vi.fn(() => Effect.succeed([{ id: 'c1' }]));
    const db = {
      select: () => ({
        from: () => ({
          where: () => ({
            orderBy,
          }),
        }),
      }),
    };

    const result = await Effect.runPromise(
      getChatsForUser('user-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(result).toEqual([{ id: 'c1' }]);
    expect(orderBy).toHaveBeenCalledOnce();
  });

  it('maps chat list errors to DatabaseError', async () => {
    const orderBy = vi.fn(() => Effect.fail(new Error('boom')));
    const db = {
      select: () => ({
        from: () => ({
          where: () => ({
            orderBy,
          }),
        }),
      }),
    };

    const exit = await Effect.runPromiseExit(
      getChatsForUser('user-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(DatabaseError);
      }
    }
  });
});
