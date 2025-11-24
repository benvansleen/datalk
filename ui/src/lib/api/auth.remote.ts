import * as v from 'valibot';
import { redirect } from '@sveltejs/kit';
import { form, getRequestEvent, query } from '$app/server';
import { getAuth } from '$lib/server/auth';

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
  try {
    await getAuth().api.signUpEmail({ body: user });
  } catch (err) {
    console.log(err);
    return { error: "There's already an account associated with this email." };
  }
  redirect(307, `/`);
});

export const login = form(LoginS, async (user) => {
  const {
    request: { headers },
  } = getRequestEvent();
  try {
    await getAuth().api.signInEmail({ body: user, headers });
  } catch (err: unknown) {
    console.log(err);
    return { error: 'No account exists with this email/password combination.' };
  }
  redirect(303, `/`);
});

export const signout = form(async () => {
  const {
    request: { headers },
  } = getRequestEvent();
  await getAuth().api.signOut({ headers });
  redirect(303, `/login`);
});

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
