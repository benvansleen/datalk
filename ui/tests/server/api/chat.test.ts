import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option, Stream } from 'effect';
import { createClient } from 'redis';
import { makeXReadScript } from '../../helpers/redis-stream';
import {
  markGenerationComplete,
  publishChatStatus,
  publishGenerationEvent,
  subscribeChatStatus,
  subscribeGenerationEvents,
} from '$lib/server/api/chat';
import { Redis } from '$lib/server/services/Redis';
import { RedisSubscriber } from '$lib/server/services/RedisSubscriber';
import { Config } from '$lib/server/services/Config';
import { RedisError } from '$lib/server/errors';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

vi.mock('redis', () => ({
  createClient: vi.fn(),
}));

describe('chat api helpers', () => {
  beforeEach(() => {
    stubConfigEnv();
  });

  afterEach(() => {
    resetConfigEnv();
    vi.clearAllMocks();
  });

  it('publishes status and generation events', async () => {
    const publish = vi.fn(() => Effect.succeed(1));
    const xAdd = vi.fn(() => Effect.succeed('1-0'));
    const expire = vi.fn(() => Effect.succeed(1));

    const redis = { publish, xAdd, expire };

    const layer = Layer.succeed(Redis, redis as never);

    await Effect.runPromise(
      publishChatStatus({ type: 'chat-created', userId: 'u1', chatId: 'c1' }).pipe(
        Effect.provide(layer),
      ),
    );
    await Effect.runPromise(
      publishGenerationEvent('req-1', { type: 'text-start', id: '1' }).pipe(Effect.provide(layer)),
    );
    await Effect.runPromise(markGenerationComplete('req-1').pipe(Effect.provide(layer)));

    expect(publish).toHaveBeenCalledWith(
      'chat-status',
      JSON.stringify({ type: 'chat-created', userId: 'u1', chatId: 'c1' }),
    );
    expect(xAdd).toHaveBeenCalledWith(
      'gen:req-1:stream',
      { event: JSON.stringify({ type: 'text-start', id: '1' }) },
      { maxLen: 10000 },
    );
    expect(expire).toHaveBeenCalledWith('gen:req-1:stream', 3600);
  });

  it('filters chat status events by user', async () => {
    const subscriber = {
      subscribeToChannelJson: () =>
        Stream.fromIterable([
          { type: 'chat-created', userId: 'u1', chatId: 'c1' },
          { type: 'chat-created', userId: 'u2', chatId: 'c2' },
        ]),
    };

    const layer = Layer.succeed(RedisSubscriber, subscriber as never);

    const result = await Effect.runPromise(
      Stream.runCollect(subscribeChatStatus('u1')).pipe(Effect.provide(layer)),
    );

    expect(Array.from(result)).toEqual([{ type: 'chat-created', userId: 'u1', chatId: 'c1' }]);
  });

  it('returns only historical events when generation already completed', async () => {
    const xRange = vi.fn(() =>
      Effect.succeed([
        {
          id: '1-0',
          message: { event: JSON.stringify({ type: 'text-delta', id: '1', delta: 'a' }) },
        },
        {
          id: '2-0',
          message: { event: JSON.stringify({ type: 'response_done' }) },
        },
      ]),
    );

    const redis = { xRange };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue({} as never);

    const layer = Layer.merge(Layer.succeed(Redis, redis as never), Config.Default);

    const result = await Effect.runPromise(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(Array.from(result)).toEqual([
      { type: 'text-delta', id: '1', delta: 'a' },
      { type: 'response_done' },
    ]);
    expect(mockedCreateClient).not.toHaveBeenCalled();
  });

  it('streams live events after replaying history', async () => {
    const xRange = vi.fn(() =>
      Effect.succeed([
        {
          id: '1-0',
          message: { event: JSON.stringify({ type: 'text-start', id: '1' }) },
        },
      ]),
    );

    const xRead = vi.fn(
      makeXReadScript([
        [{ id: '2-0', event: { type: 'text-delta', id: '1', delta: 'hi' } }],
        [{ id: '3-0', event: { type: 'response_done' } }],
      ]),
    );

    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      xRead,
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const layer = Layer.merge(Layer.succeed(Redis, { xRange } as never), Config.Default);

    const result = await Effect.runPromise(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(Array.from(result)).toEqual([
      { type: 'text-start', id: '1' },
      { type: 'text-delta', id: '1', delta: 'hi' },
      { type: 'response_done' },
    ]);
    expect(mockClient.connect).toHaveBeenCalledOnce();
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });

  it('skips malformed historical events', async () => {
    const xRange = vi.fn(() =>
      Effect.succeed([
        { id: '1-0', message: { event: 'not-json' } },
        {
          id: '2-0',
          message: { event: JSON.stringify({ type: 'response_done' }) },
        },
      ]),
    );

    const redis = { xRange };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue({} as never);

    const layer = Layer.merge(Layer.succeed(Redis, redis as never), Config.Default);

    const result = await Effect.runPromise(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(Array.from(result)).toEqual([{ type: 'response_done' }]);
  });

  it('surfaces history failures as RedisError', async () => {
    const xRange = vi.fn(() => Effect.fail(new RedisError({ message: 'boom' })));

    const layer = Layer.merge(Layer.succeed(Redis, { xRange } as never), Config.Default);

    const exit = await Effect.runPromiseExit(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(RedisError);
      }
    }
  });

  it('starts live reads from id 0 when no history exists', async () => {
    const xRange = vi.fn(() => Effect.succeed([]));

    const xRead = vi.fn(makeXReadScript([[{ id: '1-0', event: { type: 'response_done' } }]]));

    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      xRead,
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const layer = Layer.merge(Layer.succeed(Redis, { xRange } as never), Config.Default);

    await Effect.runPromise(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(xRead).toHaveBeenCalledWith(
      { key: 'gen:req-1:stream', id: '0' },
      { BLOCK: 1000, COUNT: 100 },
    );
  });

  it('shuts down the live reader after completion', async () => {
    const xRange = vi.fn(() => Effect.succeed([]));

    const xRead = vi
      .fn()
      .mockImplementationOnce(makeXReadScript([[{ id: '1-0', event: { type: 'response_done' } }]]))
      .mockImplementation(() => {
        throw new Error('unexpected read');
      });

    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      xRead,
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const layer = Layer.merge(Layer.succeed(Redis, { xRange } as never), Config.Default);

    await Effect.runPromise(
      Stream.runCollect(subscribeGenerationEvents('req-1')).pipe(Effect.provide(layer)),
    );

    expect(xRead.mock.calls.length).toBeGreaterThanOrEqual(1);
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });
});
