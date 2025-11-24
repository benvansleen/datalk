import * as v from 'valibot';
import { redirect } from '@sveltejs/kit';
import { form, getRequestEvent, query } from '$app/server';
import { auth } from '$lib/server/auth';

const SignupS = v.object({
  name: v.pipe(v.string(), v.minLength(3)),
  email: v.pipe(v.string(), v.email()),
  password: v.pipe(v.string(), v.minLength(8)),
});
const LoginS = v.object({
  email: v.pipe(v.string(), v.email()),
  password: v.pipe(v.string(), v.minLength(8)),
});

export const signup = form(SignupS, async (user) => {
  await auth.api.signUpEmail({ body: user });
  redirect(307, '/');
});

export const login = form(LoginS, async (user) => {
  const {
    request: { headers },
  } = getRequestEvent();
  await auth.api.signInEmail({ body: user, headers });
  redirect(303, '/');
});

export const signout = form(async () => {
  const {
    request: { headers },
  } = getRequestEvent();
  await auth.api.signOut({ headers });
  redirect(303, '/login');
});

export const requireAuth = query(async () => {
  const { locals: user } = getRequestEvent();
  if (!user || Object.keys(user).length === 0) {
    redirect(307, '/login');
  }
  return user;
});
