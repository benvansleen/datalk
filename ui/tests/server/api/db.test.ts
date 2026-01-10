import { describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option } from 'effect';
import {
  requireChatOwnership,
  getMessageRequest,
  getChatWithHistory,
  getChatsForUser,
  createChat,
  deleteChat,
  updateChatTitle,
  clearCurrentMessageRequest,
} from '$lib/server/api/db';
import { Database } from '$lib/server/services/Database';
import { AuthError, DatabaseError } from '$lib/server/errors';

const makeLayer = (db: unknown) => Layer.succeed(Database, db as never);

describe('db api helpers', () => {
  it('rejects when chat ownership is missing', async () => {
    const db = {
      query: {
        chat: {
          findFirst: () => Effect.fail(new AuthError({ message: 'nope' })),
        },
      },
    };

    const exit = await Effect.runPromiseExit(
      requireChatOwnership('user-1', 'chat-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(AuthError);
      }
    }
  });

  it('returns message requests when present', async () => {
    const db = {
      select: () => ({
        from: () => ({
          where: () => ({
            limit: () => Effect.succeed([{ id: 'mr-1', content: 'Hello' }]),
          }),
        }),
      }),
    };

    const result = await Effect.runPromise(
      getMessageRequest('mr-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(Option.isSome(result)).toBe(true);

    if (Option.isSome(result)) {
      expect(result.value?.content).toBe('Hello');
    }
  });

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
            Effect.succeed({ id: 'chat-1', userId: 'user-1', currentMessageRequest: 'req-1' }),
        },
        chatMessage: {
          findMany: () => Effect.succeed([]),
        },
      },
      select: () => ({
        from: () => ({
          where: () => ({
            limit: () => Effect.succeed([{ content: 'pending' }]),
          }),
        }),
      }),
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
            Effect.succeed({ id: 'chat-1', userId: 'user-1', currentMessageRequest: null }),
        },
        chatMessage: {
          findMany: () =>
            Effect.succeed([
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
            ]),
        },
      },
      select: () => ({
        from: () => ({
          where: () => ({
            limit: () => Effect.succeed([{ content: 'ignored' }]),
          }),
        }),
      }),
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

  it('creates a chat and returns its id', async () => {
    const returning = vi.fn(() => Effect.succeed([{ chatId: 'chat-1' }]));
    const db = {
      insert: () => ({
        values: () => ({
          returning,
        }),
      }),
    };

    const result = await Effect.runPromise(
      createChat('user-1', 'dataset-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(result).toBe('chat-1');
    expect(returning).toHaveBeenCalledOnce();
  });

  it('maps chat creation errors to DatabaseError', async () => {
    const returning = vi.fn(() => Effect.fail(new Error('boom')));
    const db = {
      insert: () => ({
        values: () => ({
          returning,
        }),
      }),
    };

    const exit = await Effect.runPromiseExit(
      createChat('user-1', 'dataset-1').pipe(Effect.provide(makeLayer(db))),
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

  it('maps update failures to DatabaseError', async () => {
    const where = vi.fn(() => Effect.fail(new Error('boom')));
    const db = {
      update: () => ({
        set: () => ({
          where,
        }),
      }),
    };

    const exit = await Effect.runPromiseExit(
      updateChatTitle('chat-1', 'Title').pipe(Effect.provide(makeLayer(db))),
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

  it('clears current message request', async () => {
    const where = vi.fn(() => Effect.succeed(undefined));
    const db = {
      update: () => ({
        set: () => ({
          where,
        }),
      }),
    };

    await Effect.runPromise(
      clearCurrentMessageRequest('chat-1').pipe(Effect.provide(makeLayer(db))),
    );

    expect(where).toHaveBeenCalledOnce();
  });

  it('maps delete failures to DatabaseError', async () => {
    const where = vi.fn(() => Effect.fail(new Error('boom')));
    const db = {
      delete: () => ({
        where,
      }),
    };

    const exit = await Effect.runPromiseExit(
      deleteChat('user-1', 'chat-1').pipe(Effect.provide(makeLayer(db))),
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
