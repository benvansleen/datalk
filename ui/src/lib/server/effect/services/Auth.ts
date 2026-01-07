import { Effect, Option } from 'effect';
import { Config } from './Config';
import { Database, DatabaseLive } from './Database';
import { AuthError, WhitelistError } from '../errors';
import type { SignupRequest, LoginRequest } from '../schemas/auth';
import { drizzleAdapter } from 'better-auth/adapters/drizzle';
import { betterAuth } from 'better-auth';
import { sveltekitCookies } from 'better-auth/svelte-kit';
import { getRequestEvent } from '$app/server';

const WHITELIST_SIGNUPS = new Set([
  'benvansleen@gmail.com',
  'jbm@textql.com',
  'mark@textql.com',
]);

export class Auth extends Effect.Service<Auth>()("app/Auth", {
  effect: Effect.gen(function*() {
      const config = yield* Config;
      const db = yield* Database;
      
      const auth = betterAuth({
      database: drizzleAdapter(db, { provider: 'pg' }),
      plugins: [sveltekitCookies(getRequestEvent)],
      emailAndPassword: { enabled: true },
    });

      const signup = Effect.fn('Auth.signup')(function* (request: SignupRequest, headers: Headers) {
        yield* Effect.annotateCurrentSpan({ email: request.email });
        yield* Effect.logInfo('Attempting signup', JSON.stringify(request));

        if (config.isProduction && !WHITELIST_SIGNUPS.has(request.email)) {
          return yield* Effect.fail(
            new WhitelistError({ message: '**Extremely** private beta only!' }),
          );
        }

        const result = yield* Effect.tryPromise({
          try: () => auth.api.signUpEmail({ body: { email: request.email, name: request.name, password: request.password } }),
          catch: (error) => {
            console.error('Signup error:', error);

            const errorMessage = error instanceof Error ? error.message : String(error);
            if (
              errorMessage.includes('already') ||
              errorMessage.includes('exists') ||
              errorMessage.includes('duplicate')
            ) {
              return new AuthError({
                message: "There's already an account associated with this email.",
                code: 'EMAIL_EXISTS',
              });
            }

            return new AuthError({
              message: `Signup failed: ${errorMessage}`,
              code: 'SIGNUP_FAILED',
            });
          },
        });

        yield* Effect.logInfo('Signup successful', { email: request.email });
        return result;
      });

      const login = Effect.fn('Auth.login')(function* (request: LoginRequest, headers: Headers) {
        yield* Effect.annotateCurrentSpan({ email: request.email });
        yield* Effect.logInfo('Attempting login', { email: request.email });

        const result = yield* Effect.tryPromise({
          try: () => auth.api.signInEmail({ headers, body: request }),
          catch: (error) => {
            console.error('Login error:', error);

            return new AuthError({
              message: 'No account exists with this email/password combination.',
              code: 'INVALID_CREDENTIALS',
            });
          },
        });

        yield* Effect.logInfo('Login successful', { email: request.email });
        return result;
      });

      const logout = Effect.fn('Auth.logout')(function* (headers: Headers) {
        yield* Effect.logInfo('Signing out user');

        return yield* Effect.tryPromise({
          try: () => auth.api.signOut({ headers }),
          catch: () => new AuthError({ message: 'Signout failed' }),
        }).pipe(Effect.catchAll(() => Effect.void));
      });

      const getSession = Effect.fn('Auth.getSession')(function* (headers: Headers) {
        return Option.fromNullable(yield* Effect.tryPromise({
          try: () => auth.api.getSession({ headers }),
          catch: () => new AuthError({ message: 'Failed to get session' }),
        }));
      });

      return {
        signup,
        login,
        logout,
        getSession,
        __raw: auth,
      };
  }),
  dependencies: [DatabaseLive],
}) {};

export const AuthLive = Auth.Default;
