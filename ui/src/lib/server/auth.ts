import { betterAuth } from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { sveltekitCookies } from 'better-auth/svelte-kit';
import { db } from './db';
import { getRequestEvent } from '$app/server';

export const auth = betterAuth({
  database: drizzleAdapter(db!, {
    provider: 'pg',
  }),
  plugins: [sveltekitCookies(getRequestEvent)],
  emailAndPassword: { enabled: true },
});
