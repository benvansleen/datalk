import { Effect, Layer, Redacted, Context } from 'effect';
import { PgClient } from '@effect/sql-pg';
import * as Pg from '@effect/sql-drizzle/Pg';
import type { PgRemoteDatabase } from 'drizzle-orm/pg-proxy';
import { Config } from './Config';
import * as schema from '$lib/server/db/schema';

type DatabaseWithSchema = PgRemoteDatabase<typeof schema>;
export class Database extends Context.Tag('Database')<Database, DatabaseWithSchema>() {}

const PgClientLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    const config = yield* Config;
    return PgClient.layer({
      url: Redacted.make(config.databaseUrl),
    });
  }),
);

export const DatabaseLive = Layer.effect(
  Database,
  Pg.make({ schema }),
).pipe(Layer.provide(PgClientLive));
