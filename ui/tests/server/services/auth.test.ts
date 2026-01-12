import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { Cause, Effect, Exit, Layer, Option } from 'effect';
import type { LoginRequest, SignupRequest } from '$lib/server/schemas/auth';
import { Auth } from '$lib/server/services/Auth';
import { Config } from '$lib/server/services/Config';
import { AuthError, WhitelistError } from '$lib/server/errors';
import { resetConfigEnv, stubConfigEnv } from '../../helpers/config-env';

const mockDb = vi.hoisted(() => ({ marker: 'db' }) as const);

vi.mock('$lib/server/services/Database', async () => {
  const { Context, Layer } = await import('effect');
  const Database = Context.Tag('Database')<unknown, typeof mockDb>();
  const DatabaseLive = Layer.succeed(Database, mockDb);
  return { Database, DatabaseLive, __mockDb: mockDb };
});

const signUpEmail = vi.fn();
const signInEmail = vi.fn();
const signOut = vi.fn();
const getSession = vi.fn();

vi.mock('better-auth/adapters/drizzle', () => ({
  drizzleAdapter: vi.fn(() => ({ adapter: true })),
}));

vi.mock('better-auth/svelte-kit', () => ({
  sveltekitCookies: vi.fn(() => ({ cookies: true })),
}));

vi.mock('better-auth', () => ({
  betterAuth: vi.fn(() => ({
    api: {
      signUpEmail,
      signInEmail,
      signOut,
      getSession,
    },
  })),
}));

vi.mock('$app/server', () => ({
  getRequestEvent: vi.fn(() => ({ locals: {} })),
}));

const authLayer = Layer.provide(Auth.Default, Config.Default);

describe('Auth service', () => {
  beforeEach(() => {
    stubConfigEnv();
    vi.clearAllMocks();
  });

  afterEach(() => {
    resetConfigEnv();
  });

  it('rejects non-whitelisted signups in production', async () => {
    vi.stubEnv('ENVIRONMENT', 'production');

    const request: SignupRequest = {
      email: 'someone@example.com',
      name: 'Someone',
      password: 'password',
    };

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.signup(request);
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(authLayer)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(WhitelistError);
      }
    }
  });

  it('maps duplicate signup errors to AuthError', async () => {
    const request: SignupRequest = {
      email: 'benvansleen@gmail.com',
      name: 'Ben',
      password: 'password',
    };

    signUpEmail.mockRejectedValueOnce(new Error('already exists'));

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.signup(request);
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(authLayer)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        const error = failure.value as AuthError;
        expect(error.code).toBe('EMAIL_EXISTS');
      }
    }
  });

  it('maps invalid login errors to AuthError', async () => {
    const request: LoginRequest = {
      email: 'someone@example.com',
      password: 'bad-password',
    };

    signInEmail.mockRejectedValueOnce(new Error('invalid'));

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.login(request, new Headers());
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(authLayer)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        const error = failure.value as AuthError;
        expect(error.code).toBe('INVALID_CREDENTIALS');
      }
    }
  });

  it('swallows logout failures', async () => {
    signOut.mockRejectedValueOnce(new Error('fail'));

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.logout(new Headers());
    });

    await expect(
      Effect.runPromise(program.pipe(Effect.provide(authLayer))),
    ).resolves.toBeUndefined();
  });

  it('fails when session lookup fails', async () => {
    getSession.mockRejectedValueOnce(new Error('fail'));

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.getSession(new Headers());
    });

    const exit = await Effect.runPromiseExit(program.pipe(Effect.provide(authLayer)));

    expect(Exit.isFailure(exit)).toBe(true);

    if (Exit.isFailure(exit)) {
      const failure = Cause.failureOption(exit.cause);
      expect(Option.isSome(failure)).toBe(true);
      if (Option.isSome(failure)) {
        expect(failure.value).toBeInstanceOf(AuthError);
      }
    }
  });
});
