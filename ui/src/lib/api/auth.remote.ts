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

const WHITELIST_SIGNUPS = new Set(['benvansleen@gmail.com', 'jbm@textql.com', 'mark@textql.com']);

export const signup = form(SignupS, async (user) => {
  // Hooked up to my credit card! Let's not put it out in the world for just anyone!
  if (process.env.ENVIRONMENT === 'production' && !WHITELIST_SIGNUPS.has(user.email)) {
    return { error: '**Extremely** private beta only!' };
  }

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

  console.log('User logged in:', user);
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
