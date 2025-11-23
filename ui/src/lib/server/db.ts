import { drizzle } from 'drizzle-orm/postgres-js';
import * as schema from './schema';

let db: ReturnType<typeof drizzle> | undefined;

export function getDb() {
  if (!db) {
    const { DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME } = process.env;
    if (!DB_USER) {
      return undefined;
    }

    db = drizzle(
      `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable`,
      { schema },
    );
  }
  return db;
}
