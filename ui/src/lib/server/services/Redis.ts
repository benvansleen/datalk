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

    return {
      publish,
      subscribe,
      unsubscribe,
      lPush,
      lRange,
      set,
      get,
      client,
    } as const;
  }),
  dependencies: [Config.Default],
}) {}

export const RedisLive = Redis.Default;
