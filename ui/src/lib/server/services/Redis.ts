import { Effect, Redacted } from 'effect';
import { createClient, type RedisClientType } from 'redis';
import { Config } from './Config';
import { RedisError } from '../errors';

export class Redis extends Effect.Service<Redis>()('app/Redis', {
  scoped: Effect.gen(function* () {
    const config = yield* Config;

    yield* Effect.logInfo('Connecting to Redis');

    const client = createClient({ url: Redacted.value(config.redisUrl) }) as RedisClientType;
    yield* Effect.tryPromise({
      try: () => client.connect(),
      catch: (error) =>
        new RedisError({
          message: `Failed to connect to Redis: ${error instanceof Error ? error.message : String(error)}`,
        }),
    });

    yield* Effect.logInfo('Redis connected successfully');
    yield* Effect.addFinalizer(() =>
      Effect.gen(function* () {
        yield* Effect.logInfo('Closing Redis connection');
        yield* Effect.tryPromise(() => client.quit()).pipe(
          Effect.catchAll((error) => {
            return Effect.logWarning(`Redis cleanup error: ${error}`);
          }),
        );
      }),
    );

    // Service implementation
    const publish = (channel: string, message: string) =>
      Effect.tryPromise({
        try: () => client.publish(channel, message),
        catch: (error) =>
          new RedisError({
            message: `Failed to publish to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.publish', { attributes: { channel } }));

    const subscribe = (channel: string, callback: (message: string) => void) =>
      Effect.tryPromise({
        try: () => client.subscribe(channel, callback),
        catch: (error) =>
          new RedisError({
            message: `Failed to subscribe to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.subscribe', { attributes: { channel } }));

    const unsubscribe = (channel: string) =>
      Effect.tryPromise({
        try: () => client.unsubscribe(channel),
        catch: (error) =>
          new RedisError({
            message: `Failed to unsubscribe from ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.asVoid, Effect.withSpan('Redis.unsubscribe', { attributes: { channel } }));

    const lPush = (key: string, value: string) =>
      Effect.tryPromise({
        try: () => client.lPush(key, value),
        catch: (error) =>
          new RedisError({
            message: `Failed to lPush to ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.lPush', { attributes: { key } }));

    const lRange = (key: string, start: number, stop: number) =>
      Effect.tryPromise({
        try: () => client.lRange(key, start, stop),
        catch: (error) =>
          new RedisError({
            message: `Failed to lRange from ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.lRange', { attributes: { key, start, stop } }));

    const set = (key: string, value: string) =>
      Effect.tryPromise({
        try: () => client.set(key, value),
        catch: (error) =>
          new RedisError({
            message: `Failed to set ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.asVoid, Effect.withSpan('Redis.set', { attributes: { key } }));

    const get = (key: string) =>
      Effect.tryPromise({
        try: () => client.get(key),
        catch: (error) =>
          new RedisError({
            message: `Failed to get ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.get', { attributes: { key } }));

    // ============================================================================
    // Redis Streams
    // ============================================================================

    /**
     * Add an entry to a stream. Returns the generated entry ID.
     * Uses approximate MAXLEN trimming to bound memory usage.
     */
    const xAdd = (key: string, fields: Record<string, string>, options?: { maxLen?: number }) =>
      Effect.tryPromise({
        try: () =>
          client.xAdd(
            key,
            '*',
            fields,
            options?.maxLen
              ? { TRIM: { strategy: 'MAXLEN', strategyModifier: '~', threshold: options.maxLen } }
              : undefined,
          ),
        catch: (error) =>
          new RedisError({
            message: `Failed to xAdd to ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.xAdd', { attributes: { key } }));

    /**
     * Read a range of entries from a stream.
     * Use '-' for start to read from beginning, '+' for end to read to the end.
     */
    const xRange = (key: string, start: string, end: string, count?: number) =>
      Effect.tryPromise({
        try: () => client.xRange(key, start, end, count ? { COUNT: count } : undefined),
        catch: (error) =>
          new RedisError({
            message: `Failed to xRange from ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('Redis.xRange', { attributes: { key, start, end } }));

    /**
     * Blocking read from one or more streams.
     * Returns null if the block timeout expires with no new entries.
     */
    const xRead = (
      streams: Array<{ key: string; id: string }>,
      options?: { block?: number; count?: number },
    ) =>
      Effect.tryPromise({
        try: () =>
          client.xRead(
            streams.map((s) => ({ key: s.key, id: s.id })),
            { BLOCK: options?.block, COUNT: options?.count },
          ),
        catch: (error) =>
          new RedisError({
            message: `Failed to xRead: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('Redis.xRead', {
          attributes: { streams: streams.map((s) => s.key).join(',') },
        }),
      );

    /**
     * Set a TTL on a key (in seconds).
     */
    const expire = (key: string, seconds: number) =>
      Effect.tryPromise({
        try: () => client.expire(key, seconds),
        catch: (error) =>
          new RedisError({
            message: `Failed to expire ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.asVoid, Effect.withSpan('Redis.expire', { attributes: { key, seconds } }));

    return {
      publish,
      subscribe,
      unsubscribe,
      lPush,
      lRange,
      set,
      get,
      // Streams
      xAdd,
      xRange,
      xRead,
      expire,
      client,
    } as const;
  }),
  dependencies: [Config.Default],
}) {}

export const RedisLive = Redis.Default;
