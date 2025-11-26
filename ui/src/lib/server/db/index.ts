import { drizzle } from 'drizzle-orm/postgres-js';
import type { PostgresJsDatabase } from 'drizzle-orm/postgres-js';
import * as schema from './schema';
import { env } from '$env/dynamic/private';
import { RedisCache } from './cache';

/*
 * This is a bit strange -- but need to delay initialization (eg `once-cell`) of `db` due to nix build.
 * SvelteKit keeps trying to inject the state of `env` at **build-time** -- but due to our nixos setup,
 * these values won't be known until `systemd` attempts to start the application.
 */
let db: PostgresJsDatabase<typeof schema> | null = null;

export const getDb = () => {
  if (!db) {
    const { DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME, REDIS_HOST, REDIS_PORT } = env;
    const DB_URL = `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable`;
    db = drizzle(DB_URL, {
      schema,
      cache: new RedisCache(),
    });
  }
  return db;
};
