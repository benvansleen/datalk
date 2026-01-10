import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Effect, Stream } from 'effect';
import { createClient } from 'redis';
import { RedisSubscriber } from '$lib/server/services/RedisSubscriber';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

vi.mock('redis', () => ({
  createClient: vi.fn(),
}));

describe('RedisSubscriber service', () => {
  beforeEach(() => {
    stubConfigEnv();
  });

  afterEach(() => {
    resetConfigEnv();
    vi.clearAllMocks();
  });

  it('parses JSON messages and filters invalid payloads', async () => {
    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      subscribe: vi.fn().mockImplementation(async (_channel, callback) => {
        callback('{"type":"ready"}');
        callback('not-json');
        callback('{"type":"done"}');
      }),
      unsubscribe: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const stream = Stream.unwrap(
      Effect.gen(function* () {
        const subscriber = yield* RedisSubscriber;
        return subscriber.subscribeToChannelJson<{ type: string }>('chat-status');
      }),
    ).pipe(Stream.take(2));

    const result = await Effect.runPromise(
      Stream.runCollect(stream).pipe(Effect.provide(RedisSubscriber.Default)),
    );

    expect(Array.from(result)).toEqual([{ type: 'ready' }, { type: 'done' }]);
    expect(mockClient.unsubscribe).toHaveBeenCalledWith('chat-status');
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });

  it('supports custom parsers and skips thrown errors', async () => {
    const mockClient = {
      connect: vi.fn().mockResolvedValue(undefined),
      subscribe: vi.fn().mockImplementation(async (_channel, callback) => {
        callback('1');
        callback('bad');
        callback('3');
      }),
      unsubscribe: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
    };

    const mockedCreateClient = vi.mocked(createClient);
    mockedCreateClient.mockReturnValue(mockClient as never);

    const stream = Stream.unwrap(
      Effect.gen(function* () {
        const subscriber = yield* RedisSubscriber;
        return subscriber.subscribeToChannelParsed<number>('counts', (message) => {
          if (message === 'bad') {
            throw new Error('nope');
          }
          return Number(message);
        });
      }),
    ).pipe(Stream.take(2));

    const result = await Effect.runPromise(
      Stream.runCollect(stream).pipe(Effect.provide(RedisSubscriber.Default)),
    );

    expect(Array.from(result)).toEqual([1, 3]);
    expect(mockClient.unsubscribe).toHaveBeenCalledWith('counts');
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });
});
