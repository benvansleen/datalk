import { afterEach, describe, expect, it, vi } from 'vitest';
import { Effect, Layer, Stream } from 'effect';
import { RedisClientFactory } from '$lib/server/services/RedisClientFactory';
import { RedisSubscriber } from '$lib/server/services/RedisSubscriber';

describe('RedisSubscriber service', () => {
  afterEach(() => {
    vi.clearAllMocks();
  });

  const makeRedisClientFactoryLayer = (subscriberClient: { quit: () => Promise<void> }) =>
    Layer.succeed(RedisClientFactory, {
      commandClient: {} as never,
      makeSubscriberClient: () =>
        Effect.acquireRelease(Effect.succeed(subscriberClient as never), () =>
          Effect.promise(() => subscriberClient.quit()),
        ),
      makeStreamReaderClient: () => Effect.succeed({} as never),
    } as never);

  it('parses JSON messages and filters invalid payloads', async () => {
    const mockClient = {
      subscribe: vi.fn().mockImplementation(async (_channel, callback) => {
        callback('{"type":"ready"}');
        callback('not-json');
        callback('{"type":"done"}');
      }),
      unsubscribe: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
    };

    const stream = Stream.unwrap(
      Effect.gen(function* () {
        const subscriber = yield* RedisSubscriber;
        return subscriber.subscribeToChannelJson<{ type: string }>('chat-status');
      }),
    ).pipe(Stream.take(2));

    const subscriberLayer = RedisSubscriber.Default.pipe(
      Layer.provide(makeRedisClientFactoryLayer(mockClient)),
    );

    const result = await Effect.runPromise(
      Stream.runCollect(stream).pipe(Effect.provide(subscriberLayer)),
    );

    expect(Array.from(result)).toEqual([{ type: 'ready' }, { type: 'done' }]);
    expect(mockClient.unsubscribe).toHaveBeenCalledWith('chat-status');
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });

  it('supports custom parsers and skips thrown errors', async () => {
    const mockClient = {
      subscribe: vi.fn().mockImplementation(async (_channel, callback) => {
        callback('1');
        callback('bad');
        callback('3');
      }),
      unsubscribe: vi.fn().mockResolvedValue(undefined),
      quit: vi.fn().mockResolvedValue(undefined),
    };

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

    const subscriberLayer = RedisSubscriber.Default.pipe(
      Layer.provide(makeRedisClientFactoryLayer(mockClient)),
    );

    const result = await Effect.runPromise(
      Stream.runCollect(stream).pipe(Effect.provide(subscriberLayer)),
    );

    expect(Array.from(result)).toEqual([1, 3]);
    expect(mockClient.unsubscribe).toHaveBeenCalledWith('counts');
    expect(mockClient.quit).toHaveBeenCalledOnce();
  });
});
