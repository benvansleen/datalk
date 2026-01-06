import { Effect, Layer, Redacted } from 'effect';
import { PgClient } from '@effect/sql-pg';
import * as Pg from '@effect/sql-drizzle/Pg';
import { Config } from './Config';

// Create PgClient layer from Config
const PgClientLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    const config = yield* Config;
    return PgClient.layer({
      // PgClient expects a Redacted url for security
      url: Redacted.make(config.databaseUrl),
    });
  }),
);

// PgDrizzle layer depends on PgClient
// This gives us access to Drizzle's query builder with Effect integration
export const DatabaseLive = Pg.layer.pipe(Layer.provideMerge(PgClientLive));

// Re-export PgDrizzle for use in effects
export { Pg as Database };
export const { PgDrizzle } = Pg;
