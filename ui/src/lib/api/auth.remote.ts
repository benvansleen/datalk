import { redirect } from '@sveltejs/kit';
import { form, getRequestEvent, query, command } from '$app/server';
import { effectSignup, effectLogin, effectLogout } from '$lib/server/effect/api/auth';
import { LoginRequest, SignupRequest } from '$lib/server/effect';
import { Schema } from 'effect';

// Signup - delegates to Effect implementation
export const signup = form(Schema.standardSchemaV1(SignupRequest), async (user) => {
  return await effectSignup(user);
});

// Login - delegates to Effect implementation
export const login = form(Schema.standardSchemaV1(LoginRequest), async (user) => {
  return await effectLogin(user);
});

// Logout - delegates to Effect implementation
export const logout = command(async () => {
  return await effectLogout();
});

// These don't need Effect (just read from locals)
export const requireAuth = query(async () => {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, `/login`);
  }
  return user;
});

export const alreadyLoggedIn = query(async () => {
  const {
    locals: { user },
  } = getRequestEvent();
  if (user) {
    redirect(307, `/`);
  }
});
