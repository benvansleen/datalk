import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Option } from 'effect';
import { createClient } from 'redis';
import { Redis } from '$lib/server/services/Redis';
import { RedisError } from '$lib/server/errors';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

vi.mock('redis', () => ({
  createClient: vi.fn(),
}));

describe('Redis service', () => {
  beforeEach(() => {
    stubConfigEnv();
  });

  afterEach(() => {
    resetConfigEnv();
    vi.clearAllMocks();
  });

  it('publishes messages and closes the connection', async () => {
    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      publish: vi.fn().mockResolvedValue(1),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.publish('chat-status', 'payload');
      }),
    );

    await Effect.runPromise(program.pipe(Effect.provide(Redis.Default)));

    expect(mockClient.connect).toHaveBeenCalledOnce();
    expect(mockClient.publish).toHaveBeenCalledWith('chat-status', 'payload');
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });

  it('maps publish failures to RedisError', async () => {
    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      publish: vi.fn().mockRejectedValue(new Error('boom')),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.publish('chat-status', 'payload');
      }),
    );

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(Redis.Default)));

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
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      lPush: vi.fn().mockResolvedValue(2),
      lRange: vi.fn().mockResolvedValue(['a', 'b']),
      set: vi.fn().mockResolvedValue('OK'),
      get: vi.fn().mockResolvedValue('value'),
      xAdd: vi.fn().mockResolvedValue('1-0'),
      xRange: vi.fn().mockResolvedValue([{ id: '1-0', message: { event: 'payload' } }]),
      xRead: vi.fn().mockResolvedValue([
        {
          messages: [{ id: '2-0', message: { event: 'payload-2' } }],
        },
      ]),
      expire: vi.fn().mockResolvedValue(1),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.lPush('key', 'value');
        const range = yield* redis.lRange('key', 0, 10);
        yield* redis.set('cache:key', 'value');
        const cached = yield* redis.get('cache:key');
        const added = yield* redis.xAdd('stream', { event: 'payload' }, { maxLen: 5 });
        const history = yield* redis.xRange('stream', '-', '+');
        const live = yield* redis.xRead([{ key: 'stream', id: '0' }], { block: 500, count: 1 });
        yield* redis.expire('stream', 60);
        return { range, cached, added, history, live };
      }),
    );

    const result = await Effect.runPromise(program.pipe(Effect.provide(Redis.Default)));

    expect(result.range).toEqual(['a', 'b']);
    expect(result.cached).toBe('value');
    expect(result.added).toBe('1-0');
    expect(result.history[0]?.id).toBe('1-0');
    expect(result.live?.[0]?.messages[0]?.id).toBe('2-0');
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
    expect(mockClient.xRead).toHaveBeenCalledWith([{ key: 'stream', id: '0' }], {
      BLOCK: 500,
      COUNT: 1,
    });
  });

  it('maps stream failures to RedisError', async () => {
    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
      xRead: vi.fn().mockRejectedValue(new Error('boom')),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const program = Effect.scoped(
      Effect.gen(function* () {
        const redis = yield* Redis;
        yield* redis.xRead([{ key: 'stream', id: '0' }]);
      }),
    );

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(Redis.Default)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(RedisError);
      }
    }
  });
});
