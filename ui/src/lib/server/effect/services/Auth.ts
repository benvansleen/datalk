import { Effect, Context, Layer } from 'effect';
import { getAuth } from '$lib/server/auth';
import { Config } from './Config';
import { AuthError, WhitelistError } from '../errors';
import type { SignupRequest, LoginRequest } from '../schemas/auth';

const WHITELIST_SIGNUPS = new Set([
  'benvansleen@gmail.com',
  'jbm@textql.com',
  'mark@textql.com',
]);

// Auth service interface
export interface AuthService {
  readonly signup: (
    request: SignupRequest,
    headers: Headers,
  ) => Effect.Effect<unknown, AuthError | WhitelistError, never>;
  readonly login: (
    request: LoginRequest,
    headers: Headers,
  ) => Effect.Effect<unknown, AuthError, never>;
  readonly logout: (headers: Headers) => Effect.Effect<void, never, never>;
  readonly getSession: (headers: Headers) => Effect.Effect<unknown, AuthError, never>;
}

// Auth service tag
export class Auth extends Context.Tag('Auth')<Auth, AuthService>() {
  // Create a layer that provides Auth by using the existing getAuth() singleton
  // This works because getAuth() is designed to be called during requests
  static readonly Default = Layer.effect(
    Auth,
    Effect.gen(function* () {
      const config = yield* Config;

      // Return methods that use getAuth() at call time (during request)
      // rather than at service construction time
      const signup = Effect.fn('Auth.signup')(function* (request: SignupRequest, headers: Headers) {
        yield* Effect.annotateCurrentSpan({ email: request.email });

        // Check whitelist in production
        if (config.isProduction && !WHITELIST_SIGNUPS.has(request.email)) {
          return yield* Effect.fail(
            new WhitelistError({ message: '**Extremely** private beta only!' }),
          );
        }

        yield* Effect.logInfo('Attempting signup', JSON.stringify(request));

        const result = yield* Effect.tryPromise({
          try: () => getAuth().api.signUpEmail({ body: { email: request.email, name: request.name, password: request.password } }),
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
          try: () => getAuth().api.signInEmail({ headers, body: request }),
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
          try: () => getAuth().api.signOut({ headers }),
          catch: () => new AuthError({ message: 'Signout failed' }),
        }).pipe(Effect.catchAll(() => Effect.void));
      });

      const getSession = Effect.fn('Auth.getSession')(function* (headers: Headers) {
        return yield* Effect.tryPromise({
          try: () => getAuth().api.getSession({ headers }),
          catch: () => new AuthError({ message: 'Failed to get session' }),
        });
      });

      return {
        signup,
        login,
        logout,
        getSession,
      } satisfies AuthService;
    }),
  );
}

// Re-export for convenience
export const AuthLive = Auth.Default;
