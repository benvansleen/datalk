import { Effect, Either, Redacted, Schema } from 'effect';
import { createClient } from 'redis';
import { Config } from './Config';
import { RedisError } from '../errors';

type RedisLogLevel = 'info' | 'debug';

type ClientOptions = {
  label: string;
  logLevel: RedisLogLevel;
};

const RedisStreamReadResultSchema = Schema.Array(
  Schema.Struct({
    messages: Schema.Array(
      Schema.Struct({
        id: Schema.String,
        message: Schema.Record({ key: Schema.String, value: Schema.String }),
      }),
    ),
  }),
);

export type RedisStreamReadResult = typeof RedisStreamReadResultSchema.Type;

export const normalizeRedisStreamReadResult = (value: unknown): RedisStreamReadResult | null =>
  Either.match(Schema.decodeUnknownEither(RedisStreamReadResultSchema)(value), {
    onLeft: () => null,
    onRight: (result) => result,
  });

export class RedisClientFactory extends Effect.Service<RedisClientFactory>()('app/RedisClientFactory', {
  scoped: Effect.gen(function* () {
    const config = yield* Config;

    const createConnectedClient = ({ label, logLevel }: ClientOptions) =>
      Effect.gen(function* () {
        const log = logLevel === 'info' ? Effect.logInfo : Effect.logDebug;
        yield* log(`Connecting to Redis (${label})`);

        const client = createClient({ url: Redacted.value(config.redisUrl) });
        yield* Effect.tryPromise({
          try: () => client.connect(),
          catch: (error) =>
            new RedisError({
              message: `Failed to connect Redis ${label}: ${
                error instanceof Error ? error.message : String(error)
              }`,
            }),
        });

        yield* log(`Redis connected (${label})`);
        yield* Effect.addFinalizer(() =>
          Effect.gen(function* () {
            yield* log(`Closing Redis connection (${label})`);
            yield* Effect.tryPromise(() => client.quit()).pipe(
              Effect.catchAll((error) => Effect.logWarning(`Redis cleanup error: ${error}`)),
            );
          }),
        );

        return client;
      });

    const commandClient = yield* createConnectedClient({ label: 'command', logLevel: 'info' });

    const makeSubscriberClient = () =>
      createConnectedClient({ label: 'subscriber', logLevel: 'debug' });

    const makeStreamReaderClient = () =>
      createConnectedClient({ label: 'stream-reader', logLevel: 'debug' });

    return {
      commandClient,
      makeSubscriberClient,
      makeStreamReaderClient,
    } as const;
  }),
  dependencies: [Config.Default],
}) {}

export const RedisClientFactoryLive = RedisClientFactory.Default;
