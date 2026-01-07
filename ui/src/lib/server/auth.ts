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
import { redirect } from '@sveltejs/kit';

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

/**
 * Get the current user or null if not authenticated.
 * Use this in remote functions (query/form) where you need to handle
 * the redirect manually.
 */
export const getUser = () => {
  const {
    locals: { user },
  } = getRequestEvent();
  return user ?? null;
};

/**
 * Require authentication and throw a redirect if not authenticated.
 * Use this in +server.ts files where SvelteKit will catch the redirect.
 * 
 * WARNING: Do not use in remote functions (query/form) - use getUser() instead
 * and handle the redirect at the call site.
 */
export const requireAuth = () => {
  const user = getUser();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
};
