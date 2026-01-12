import { Effect } from 'effect';
import { normalizeRedisStreamReadResult, RedisClientFactory } from './RedisClientFactory';
import { RedisError } from '../errors';

type ReadBlockingOptions = {
  key: string;
  id: string;
  block?: number;
  count?: number;
  suppressErrors?: () => boolean;
};

export class RedisStreamReader extends Effect.Service<RedisStreamReader>()(
  'app/RedisStreamReader',
  {
    scoped: Effect.gen(function* () {
      const factory = yield* RedisClientFactory;
      const client = yield* factory.makeStreamReaderClient();

      const readBlocking = (options: ReadBlockingOptions) =>
        Effect.tryPromise({
          try: () =>
            client.xRead(
              { key: options.key, id: options.id },
              { BLOCK: options.block, COUNT: options.count },
            ),
          catch: (error) => {
            if (options.suppressErrors?.()) {
              return null;
            }
            return new RedisError({
              message: `Failed to xRead: ${error instanceof Error ? error.message : String(error)}`,
            });
          },
        }).pipe(Effect.map(normalizeRedisStreamReadResult));

      return { readBlocking } as const;
    }),
  },
) {}

export const RedisStreamReaderLive = RedisStreamReader.Default;
