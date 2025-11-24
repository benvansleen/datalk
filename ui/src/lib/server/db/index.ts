import { drizzle } from 'drizzle-orm/postgres-js';
import * as schema from './schema';
import { env } from '$env/dynamic/private';

const { DB_USER, DB_PASSWORD, DB_HOST, DB_PORT, DB_NAME } = env;
if (!DB_PASSWORD) throw new Error('Database configuration unset');

export const db = drizzle(
  `postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable`,
  { schema },
);
