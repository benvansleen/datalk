import { Effect } from 'effect';
import { createClient, type RedisClientType } from 'redis';
import { Config } from './Config';
import { RedisError } from '../errors';

export class Redis extends Effect.Service<Redis>()("app/Redis", {
  scoped: Effect.gen(function*() {
      const config = yield* Config;

      yield* Effect.logInfo('Connecting to Redis');

      // Create and connect the client
      const client = createClient({ url: config.redisUrl }) as RedisClientType;

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
        }).pipe(
          Effect.asVoid,
          Effect.withSpan('Redis.unsubscribe', { attributes: { channel } }),
        );

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
        }).pipe(
          Effect.asVoid,
          Effect.withSpan('Redis.set', { attributes: { key } }),
        );

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
      };
  }),
  dependencies: [Config.Default],
}) {};

// Type for the underlying Redis client
// type RedisClient = RedisClientType;
//
// // Redis service interface
// export interface RedisService {
//   /**
//    * Publish a message to a channel
//    */
//   readonly publish: (channel: string, message: string) => Effect.Effect<number, RedisError, never>;
//
//   /**
//    * Subscribe to a channel with a callback
//    * Returns an unsubscribe effect
//    */
//   readonly subscribe: (
//     channel: string,
//     callback: (message: string) => void,
//   ) => Effect.Effect<void, RedisError, never>;
//
//   /**
//    * Unsubscribe from a channel
//    */
//   readonly unsubscribe: (channel: string) => Effect.Effect<void, RedisError, never>;
//
//   /**
//    * Push a value to the left of a list
//    */
//   readonly lPush: (key: string, value: string) => Effect.Effect<number, RedisError, never>;
//
//   /**
//    * Get a range of values from a list
//    */
//   readonly lRange: (
//     key: string,
//     start: number,
//     stop: number,
//   ) => Effect.Effect<string[], RedisError, never>;
//
//   /**
//    * Set a key-value pair
//    */
//   readonly set: (key: string, value: string) => Effect.Effect<void, RedisError, never>;
//
//   /**
//    * Get a value by key
//    */
//   readonly get: (key: string) => Effect.Effect<string | null, RedisError, never>;
//
//   /**
//    * Get the underlying client for advanced operations
//    * Use sparingly - prefer the typed methods above
//    */
//   readonly client: RedisClient;
// }
//
// // Redis service tag
// export class Redis extends Context.Tag('Redis')<Redis, RedisService>() {
//   /**
//    * Create a Redis layer with scoped connection management.
//    * The connection is automatically closed when the scope ends.
//    */
//   static readonly Default = Layer.scoped(
//     Redis,
//     Effect.gen(function* () {
//       const config = yield* Config;
//
//       yield* Effect.logInfo('Connecting to Redis');
//
//       // Create and connect the client
//       const client = createClient({ url: config.redisUrl }) as RedisClient;
//
//       yield* Effect.tryPromise({
//         try: () => client.connect(),
//         catch: (error) =>
//           new RedisError({
//             message: `Failed to connect to Redis: ${error instanceof Error ? error.message : String(error)}`,
//           }),
//       });
//
//       yield* Effect.logInfo('Redis connected successfully');
//
//       // Register cleanup when scope closes
//       yield* Effect.addFinalizer(() =>
//         Effect.gen(function* () {
//           yield* Effect.logInfo('Closing Redis connection');
//           yield* Effect.tryPromise(() => client.quit()).pipe(
//             Effect.catchAll((error) => {
//               // Log but don't fail on cleanup errors
//               return Effect.logWarning(`Redis cleanup error: ${error}`);
//             }),
//           );
//         }),
//       );
//
//       // Service implementation
//       const publish = (channel: string, message: string) =>
//         Effect.tryPromise({
//           try: () => client.publish(channel, message),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to publish to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(Effect.withSpan('Redis.publish', { attributes: { channel } }));
//
//       const subscribe = (channel: string, callback: (message: string) => void) =>
//         Effect.tryPromise({
//           try: () => client.subscribe(channel, callback),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to subscribe to ${channel}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(Effect.withSpan('Redis.subscribe', { attributes: { channel } }));
//
//       const unsubscribe = (channel: string) =>
//         Effect.tryPromise({
//           try: () => client.unsubscribe(channel),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to unsubscribe from ${channel}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(
//           Effect.asVoid,
//           Effect.withSpan('Redis.unsubscribe', { attributes: { channel } }),
//         );
//
//       const lPush = (key: string, value: string) =>
//         Effect.tryPromise({
//           try: () => client.lPush(key, value),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to lPush to ${key}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(Effect.withSpan('Redis.lPush', { attributes: { key } }));
//
//       const lRange = (key: string, start: number, stop: number) =>
//         Effect.tryPromise({
//           try: () => client.lRange(key, start, stop),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to lRange from ${key}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(Effect.withSpan('Redis.lRange', { attributes: { key, start, stop } }));
//
//       const set = (key: string, value: string) =>
//         Effect.tryPromise({
//           try: () => client.set(key, value),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to set ${key}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(
//           Effect.asVoid,
//           Effect.withSpan('Redis.set', { attributes: { key } }),
//         );
//
//       const get = (key: string) =>
//         Effect.tryPromise({
//           try: () => client.get(key),
//           catch: (error) =>
//             new RedisError({
//               message: `Failed to get ${key}: ${error instanceof Error ? error.message : String(error)}`,
//             }),
//         }).pipe(Effect.withSpan('Redis.get', { attributes: { key } }));
//
//       return {
//         publish,
//         subscribe,
//         unsubscribe,
//         lPush,
//         lRange,
//         set,
//         get,
//         client,
//       } satisfies RedisService;
//     }),
//   ).pipe(Layer.provide(Config.Default));
// }
//
// // Re-export for convenience
export const RedisLive = Redis.Default;
