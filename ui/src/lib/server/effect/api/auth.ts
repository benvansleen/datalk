import { Effect, Schema, Exit } from 'effect';
import { redirect } from '@sveltejs/kit';
import { getRequestEvent } from '$app/server';
import { Auth } from '../services/Auth';
import { SignupRequest, LoginRequest } from '../schemas/auth';
import { AuthError, WhitelistError } from '../errors';
import { runEffectExit, getFailure, runEffect } from '../runtime';

/**
 * Effect-based signup handler
 * Called from the existing form handler to gradually migrate without changing the UI
 */
export const effectSignup = async (request: SignupRequest): Promise<{ error?: string } | never> => {
  const event = getRequestEvent();
  const headers = event.request.headers;

  const program = Effect.gen(function* () {
    const auth = yield* Auth;
    yield* auth.signup(request, headers);
  }).pipe(Effect.withSpan('auth.signup'));

  const exit = await runEffectExit(program);

  if (Exit.isSuccess(exit)) {
    redirect(307, '/');
  }

  // Handle typed errors
  const error = getFailure(exit);
  if (error instanceof WhitelistError) {
    return { error: error.message };
  }
  if (error instanceof AuthError) {
    return { error: error.message };
  }

  return { error: 'An unexpected error occurred' };
};

/**
 * Effect-based login handler
 */
export const effectLogin = async (request: LoginRequest): Promise<{ error?: string } | never> => {
  const event = getRequestEvent();
  const headers = event.request.headers;

  const program = Effect.gen(function* () {
    const auth = yield* Auth;
    yield* auth.login(request, headers);
  }).pipe(Effect.withSpan('auth.login'));

  const exit = await runEffectExit(program);

  if (Exit.isSuccess(exit)) {
    redirect(303, '/');
  }

  const error = getFailure(exit);
  if (error instanceof AuthError) {
    return { error: error.message };
  }

  return { error: 'An unexpected error occurred' };
};

/**
 * Effect-based signout handler
 */
export const effectLogout = async (): Promise<void> => {
  const event = getRequestEvent();
  const headers = event.request.headers;

  const program = Effect.gen(function* () {
    const auth = yield* Auth;
    yield* auth.logout(headers);
  }).pipe(Effect.withSpan('auth.logout'));

  await runEffect(program);
};
