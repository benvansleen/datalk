import { Effect, Redacted, Stream } from 'effect';
import { createClient, type RedisClientType } from 'redis';
import { Config } from './Config';
import { RedisError } from '../errors';

/**
 * RedisSubscriber service for creating pub/sub streams.
 *
 * Each subscription creates its own dedicated Redis connection (required by Redis pub/sub).
 * Connections are automatically cleaned up when streams end.
 */
export class RedisSubscriber extends Effect.Service<RedisSubscriber>()('app/RedisSubscriber', {
  dependencies: [Config.Default],
  effect: Effect.gen(function* () {
    const config = yield* Config;

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

            // Create a dedicated client for this subscription
            const client = createClient({
              url: Redacted.value(config.redisUrl),
            }) as RedisClientType;

            // Connect to Redis
            yield* Effect.tryPromise({
              try: () => client.connect(),
              catch: (error) =>
                new RedisError({
                  message: `Failed to connect Redis subscriber: ${error instanceof Error ? error.message : String(error)}`,
                }),
            });

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
                yield* Effect.tryPromise(() => client.quit()).pipe(
                  Effect.catchAll((error) =>
                    Effect.logWarning(`Failed to close Redis subscriber: ${error}`),
                  ),
                );
              }),
            );
          }),
        { bufferSize: 256, strategy: 'sliding' },
      ).pipe(Stream.withSpan('RedisSubscriber.subscribeToChannel', { attributes: { channel } }));

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
