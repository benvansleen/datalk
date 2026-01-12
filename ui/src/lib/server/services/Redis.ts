import { Effect } from 'effect';
import { RedisClientFactory } from './RedisClientFactory';
import { RedisError } from '../errors';

export class Redis extends Effect.Service<Redis>()('app/Redis', {
  scoped: Effect.gen(function* () {
    const factory = yield* RedisClientFactory;
    const client = factory.commandClient;

    // Service implementation
    const publish = (channel: string, message: string) =>
      Effect.tryPromise({
        try: () => client.publish(channel, message),
        catch: (error) =>
          new RedisError({
            message: `Failed to publish to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('redis PUBLISH', {
          attributes: {
            'messaging.system': 'redis',
            'messaging.operation': 'publish',
            'messaging.destination': channel,
          },
        }),
      );

    const subscribe = (channel: string, callback: (message: string) => void) =>
      Effect.tryPromise({
        try: () => client.subscribe(channel, callback),
        catch: (error) =>
          new RedisError({
            message: `Failed to subscribe to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('redis SUBSCRIBE', {
          attributes: {
            'messaging.system': 'redis',
            'messaging.operation': 'subscribe',
            'messaging.destination': channel,
          },
        }),
      );

    const unsubscribe = (channel: string) =>
      Effect.tryPromise({
        try: () => client.unsubscribe(channel),
        catch: (error) =>
          new RedisError({
            message: `Failed to unsubscribe from ${channel}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.asVoid,
        Effect.withSpan('redis UNSUBSCRIBE', {
          attributes: {
            'messaging.system': 'redis',
            'messaging.operation': 'unsubscribe',
            'messaging.destination': channel,
          },
        }),
      );

    const lPush = (key: string, value: string) =>
      Effect.tryPromise({
        try: () => client.lPush(key, value),
        catch: (error) =>
          new RedisError({
            message: `Failed to lPush to ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('redis LPUSH', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'lpush',
            'db.redis.key': key,
          },
        }),
      );

    const lRange = (key: string, start: number, stop: number) =>
      Effect.tryPromise({
        try: () => client.lRange(key, start, stop),
        catch: (error) =>
          new RedisError({
            message: `Failed to lRange from ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('redis LRANGE', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'lrange',
            'db.redis.key': key,
            'db.redis.start': start,
            'db.redis.stop': stop,
          },
        }),
      );

    const set = (key: string, value: string) =>
      Effect.tryPromise({
        try: () => client.set(key, value),
        catch: (error) =>
          new RedisError({
            message: `Failed to set ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.asVoid,
        Effect.withSpan('redis SET', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'set',
            'db.redis.key': key,
          },
        }),
      );

    const get = (key: string) =>
      Effect.tryPromise({
        // try: () => client.get(key),
        try: () => client.get(key),
        catch: (error) =>
          new RedisError({
            message: `Failed to get ${key}: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.withSpan('redis GET', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'get',
            'db.redis.key': key,
          },
        }),
      );

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
      }).pipe(
        Effect.withSpan('redis XADD', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'xadd',
            'db.redis.key': key,
          },
        }),
      );

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
      }).pipe(
        Effect.withSpan('redis XRANGE', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'xrange',
            'db.redis.key': key,
            'db.redis.start': start,
            'db.redis.end': end,
          },
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
      }).pipe(
        Effect.asVoid,
        Effect.withSpan('redis EXPIRE', {
          attributes: {
            'db.system': 'redis',
            'db.operation': 'expire',
            'db.redis.key': key,
            'db.redis.ttl_seconds': seconds,
          },
        }),
      );

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
      expire,
      client,
    } as const;
  }),
}) {}

export const RedisLive = Redis.Default;
