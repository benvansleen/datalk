import { drizzle } from 'drizzle-orm/postgres-js';
import * as schema from './schema';
import { DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME } from '$env/static/private';

export const db = drizzle(
  `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable`,
  { schema },
);
