import { query, form } from '$app/server';
import { sql } from 'drizzle-orm';
import * as v from 'valibot';

import { db } from '$lib/server/db';
import { usersTable } from '$lib/server/schema';

export const getUsers = query(async () => {
  const users = await db.execute(sql`select * from ${usersTable}`);
  return users;
});

export const createUser = form(
  v.object({
    full_name: v.pipe(v.string(), v.nonEmpty()),
    email: v.pipe(v.string(), v.nonEmpty()),
  }),
  async ({ full_name, email }) => {
    await db.execute(sql`
      INSERT INTO ${usersTable} (full_name, email)
      VALUES (${full_name}, ${email})
    `);
  },
);
