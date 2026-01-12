import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option } from 'effect';
import { Redis } from '$lib/server/services/Redis';
import { RedisClientFactory } from '$lib/server/services/RedisClientFactory';
import { RedisError } from '$lib/server/errors';

describe('Redis service', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  const makeRedisClientFactoryLayer = (commandClient: unknown) =>
    Layer.succeed(RedisClientFactory, {
      commandClient,
      makeSubscriberClient: () => Effect.succeed({} as never),
      makeStreamReaderClient: () => Effect.succeed({} as never),
    } as never);

  it('publishes messages and closes the connection', async () => {
    const mockClient = {
      publish: vi.fn().mockResolvedValue(1),
    };

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.publish('chat-status', 'payload');
      }),
    );

    const redisLayer = Redis.Default.pipe(Layer.provide(makeRedisClientFactoryLayer(mockClient)));

    await Effect.runPromise(program.pipe(Effect.provide(redisLayer)));

    expect(mockClient.publish).toHaveBeenCalledWith('chat-status', 'payload');
  });

  it('maps publish failures to RedisError', async () => {
    const mockClient = {
      publish: vi.fn().mockRejectedValue(new Error('boom')),
    };

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.publish('chat-status', 'payload');
      }),
    );

    const redisLayer = Redis.Default.pipe(Layer.provide(makeRedisClientFactoryLayer(mockClient)));

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(redisLayer)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(RedisError);
      }
    }
  });

  it('supports list and stream helpers', async () => {
    const mockClient = {
      lPush: vi.fn().mockResolvedValue(2),
      lRange: vi.fn().mockResolvedValue(['a', 'b']),
      set: vi.fn().mockResolvedValue('OK'),
      get: vi.fn().mockResolvedValue('value'),
      xAdd: vi.fn().mockResolvedValue('1-0'),
      xRange: vi.fn().mockResolvedValue([{ id: '1-0', message: { event: 'payload' } }]),
      expire: vi.fn().mockResolvedValue(1),
    };

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.lPush('key', 'value');
        const range = yield* redis.lRange('key', 0, 10);
        yield* redis.set('cache:key', 'value');
        const cached = yield* redis.get('cache:key');
        const added = yield* redis.xAdd('stream', { event: 'payload' }, { maxLen: 5 });
        const history = yield* redis.xRange('stream', '-', '+');
        yield* redis.expire('stream', 60);
        return { range, cached, added, history };
      }),
    );

    const redisLayer = Redis.Default.pipe(Layer.provide(makeRedisClientFactoryLayer(mockClient)));

    const result = await Effect.runPromise(program.pipe(Effect.provide(redisLayer)));

    expect(result.range).toEqual(['a', 'b']);
    expect(result.cached).toBe('value');
    expect(result.added).toBe('1-0');
    expect(result.history[0]?.id).toBe('1-0');
    expect(mockClient.lPush).toHaveBeenCalledWith('key', 'value');
    expect(mockClient.lRange).toHaveBeenCalledWith('key', 0, 10);
    expect(mockClient.set).toHaveBeenCalledWith('cache:key', 'value');
    expect(mockClient.get).toHaveBeenCalledWith('cache:key');
    expect(mockClient.xAdd).toHaveBeenCalledWith(
      'stream',
      '*',
      { event: 'payload' },
      { TRIM: { strategy: 'MAXLEN', strategyModifier: '~', threshold: 5 } },
    );
  });
});
