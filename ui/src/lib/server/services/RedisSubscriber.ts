import { Effect, Stream } from 'effect';
import { RedisClientFactory } from './RedisClientFactory';
import { RedisError } from '../errors';

/**
 * RedisSubscriber service for creating pub/sub streams.
 *
 * Each subscription creates its own dedicated Redis connection (required by Redis pub/sub).
 * Connections are automatically cleaned up when streams end.
 */
export class RedisSubscriber extends Effect.Service<RedisSubscriber>()('app/RedisSubscriber', {
  scoped: Effect.gen(function* () {
    const factory = yield* RedisClientFactory;

    /**
     * Creates an Effect Stream that subscribes to a Redis channel.
     *
     * @param channel - The Redis channel to subscribe to
     * @returns A Stream of messages from the channel
     */
    const subscribeToChannel = (channel: string) =>
      Stream.asyncPush<string, RedisError>(
        (emit) =>
          Effect.gen(function* () {
            yield* Effect.logDebug(`Creating Redis subscriber for channel: ${channel}`);

            const client = yield* factory.makeSubscriberClient();

            // Subscribe to the channel
            yield* Effect.tryPromise({
              try: () =>
                client.subscribe(channel, (message) => {
                  emit.single(message);
                }),
              catch: (error) =>
                new RedisError({
                  message: `Failed to subscribe to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
                }),
            });

            yield* Effect.logDebug(`Subscribed to Redis channel: ${channel}`);

            // Register finalizer to clean up when stream ends
            yield* Effect.addFinalizer(() =>
              Effect.gen(function* () {
                yield* Effect.logDebug(`Unsubscribing from Redis channel: ${channel}`);
                yield* Effect.tryPromise(() => client.unsubscribe(channel)).pipe(
                  Effect.catchAll((error) =>
                    Effect.logWarning(`Failed to unsubscribe from ${channel}: ${error}`),
                  ),
                );
              }),
            );
          }),
        { bufferSize: 256, strategy: 'sliding' },
      ).pipe(
        Stream.withSpan('redis SUBSCRIBE', {
          attributes: {
            'messaging.system': 'redis',
            'messaging.operation': 'subscribe',
            'messaging.destination': channel,
          },
        }),
      );

    /**
     * Subscribes to a channel and maps messages through a parser.
     * Messages that fail to parse are logged and skipped.
     */
    const subscribeToChannelParsed = <T>(channel: string, parser: (message: string) => T) =>
      subscribeToChannel(channel).pipe(
        Stream.map((message) => {
          try {
            return parser(message);
          } catch {
            return null;
          }
        }),
        Stream.filter((value): value is T => value !== null),
      );

    /**
     * Subscribes to a channel and parses messages as JSON.
     * Invalid JSON messages are logged and skipped.
     */
    const subscribeToChannelJson = <T = unknown>(channel: string) =>
      subscribeToChannelParsed<T>(channel, (message) => JSON.parse(message));

    return {
      subscribeToChannel,
      subscribeToChannelParsed,
      subscribeToChannelJson,
    } as const;
  }),
}) {}

export const RedisSubscriberLive = RedisSubscriber.Default;
