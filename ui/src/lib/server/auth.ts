import {
  betterAuth,
  type Auth,
  type BetterAuthOptions,
  type DBAdapter,
  type MiddlewareInputContext,
  type MiddlewareOptions,
} from 'better-auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { sveltekitCookies } from 'better-auth/svelte-kit';
import { getDb } from './db';
import { getRequestEvent } from '$app/server';

// See '$lib/server/db/index.ts' for explanation
let auth: Auth<{
  database: (options: BetterAuthOptions) => DBAdapter<BetterAuthOptions>;
  plugins: [
    {
      id: 'sveltekit-cookies';
      hooks: {
        after: {
          matcher(): true;
          handler: (inputContext: MiddlewareInputContext<MiddlewareOptions>) => Promise<void>;
        }[];
      };
    },
  ];
  emailAndPassword: { enabled: true };
}> | null = null;
export const getAuth = () => {
  if (!auth) {
    const db = getDb();
    auth = betterAuth({
      database: drizzleAdapter(db, {
        provider: 'pg',
      }),
      plugins: [sveltekitCookies(getRequestEvent)],
      emailAndPassword: { enabled: true },
    });
  }

  return auth;
};
