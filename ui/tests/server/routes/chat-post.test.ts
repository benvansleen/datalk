import { beforeEach, describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option, Stream } from 'effect';
import type { DatalkStreamPart } from '$lib/server/services/DatalkAgent';
import { DatalkAgent } from '$lib/server/services/DatalkAgent';
import { Database } from '$lib/server/services/Database';
import { Redis } from '$lib/server/services/Redis';
import { finalizeGeneration, generateResponse } from '$lib/server';

const publishChatStatusMock = vi.hoisted(() => vi.fn((event) => Effect.succeed(event)));
const publishGenerationEventMock = vi.hoisted(() =>
  vi.fn((messageId, event) => Effect.succeed({ messageId, event })),
);
const markGenerationCompleteMock = vi.hoisted(() =>
  vi.fn((messageId) => Effect.succeed(messageId)),
);

vi.mock('$lib/server/api/chat', async () => {
  const actual =
    await vi.importActual<typeof import('$lib/server/api/chat')>('$lib/server/api/chat');

  return {
    ...actual,
    publishChatStatus: publishChatStatusMock,
    publishGenerationEvent: publishGenerationEventMock,
    markGenerationComplete: markGenerationCompleteMock,
  };
});

describe('chat generation helpers', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('finalizes generation without errors', async () => {
    const db = {
      update: () => ({
        set: () => ({
          where: () => Effect.succeed(undefined),
        }),
      }),
    };

    const layer = Layer.merge(
      Layer.succeed(Database, db as never),
      Layer.succeed(Redis, {} as never),
    );

    await Effect.runPromise(
      finalizeGeneration('user-1', 'chat-1', 'msg-1').pipe(Effect.provide(layer)),
    );

    expect(publishGenerationEventMock).not.toHaveBeenCalled();
    expect(publishChatStatusMock).toHaveBeenCalledWith({
      type: 'status-changed',
      userId: 'user-1',
      chatId: 'chat-1',
      currentMessageId: null,
    });
    expect(markGenerationCompleteMock).toHaveBeenCalledWith('msg-1');
  });

  it('emits response errors during finalization', async () => {
    const db = {
      update: () => ({
        set: () => ({
          where: () => Effect.succeed(undefined),
        }),
      }),
    };

    const layer = Layer.merge(
      Layer.succeed(Database, db as never),
      Layer.succeed(Redis, {} as never),
    );

    await Effect.runPromise(
      finalizeGeneration('user-1', 'chat-1', 'msg-1', 'boom').pipe(Effect.provide(layer)),
    );

    expect(publishGenerationEventMock).toHaveBeenCalledWith('msg-1', {
      type: 'response_error',
      message: 'boom',
    });
  });

  it('streams response parts and marks completion', async () => {
    const db = {
      update: () => ({
        set: () => ({
          where: () => Effect.succeed(undefined),
        }),
      }),
    };

    const parts = [
      { type: 'text-start', id: '1' },
      { type: 'text-delta', id: '1', delta: 'Hello' },
      { type: 'text-end', id: '1' },
      { type: 'finish' },
    ] as unknown as DatalkStreamPart[];

    const agent = {
      run: () => Effect.succeed(Stream.fromIterable(parts)),
    };

    const layer = Layer.merge(
      Layer.merge(Layer.succeed(Database, db as never), Layer.succeed(DatalkAgent, agent as never)),
      Layer.succeed(Redis, {} as never),
    );

    await Effect.runPromise(
      generateResponse('user-1', 'chat-1', 'dataset-1', 'msg-1', 'Hello').pipe(
        Effect.provide(layer),
      ),
    );

    expect(publishChatStatusMock).toHaveBeenCalledWith({
      type: 'status-changed',
      userId: 'user-1',
      chatId: 'chat-1',
      currentMessageId: 'msg-1',
    });
    expect(publishGenerationEventMock).toHaveBeenCalledWith('msg-1', {
      type: 'text-start',
      id: '1',
    });
    expect(publishGenerationEventMock).toHaveBeenCalledWith('msg-1', {
      type: 'text-delta',
      id: '1',
      delta: 'Hello',
    });
    expect(markGenerationCompleteMock).toHaveBeenCalledWith('msg-1');
  });

  it('reports failures from agent streams', async () => {
    const db = {
      update: () => ({
        set: () => ({
          where: () => Effect.succeed(undefined),
        }),
      }),
    };

    const agent = {
      run: () => Effect.succeed(Stream.fail(new Error('stream failure'))),
    };

    const layer = Layer.merge(
      Layer.merge(Layer.succeed(Database, db as never), Layer.succeed(DatalkAgent, agent as never)),
      Layer.succeed(Redis, {} as never),
    );

    const exit = await Effect.runPromiseExit(
      generateResponse('user-1', 'chat-1', 'dataset-1', 'msg-1', 'Hello').pipe(
        Effect.provide(layer),
      ),
    );

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
    }

    const errorCall = publishGenerationEventMock.mock.calls.find(
      ([, event]) => event.type === 'response_error',
    );

    expect(errorCall).toBeDefined();
    expect(markGenerationCompleteMock).toHaveBeenCalledWith('msg-1');
  });
});
