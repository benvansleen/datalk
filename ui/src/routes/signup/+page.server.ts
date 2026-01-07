import type { Actions, PageServerLoad } from './$types';
import { redirect, fail } from '@sveltejs/kit';
import { Effect, Exit } from 'effect';
import { runEffectExit, getFailure } from '$lib/server/effect';
import { Auth } from '$lib/server/effect/services/Auth';
import { AuthError, WhitelistError } from '$lib/server/effect/errors';

export const load: PageServerLoad = async ({ locals }) => {
  // Redirect to home if already logged in
  if (locals.user) {
    redirect(307, '/');
  }
  return {};
};

export const actions: Actions = {
  default: async ({ request }) => {
    const formData = await request.formData();
    const name = formData.get('name') as string;
    const email = formData.get('email') as string;
    const password = formData.get('password') as string;

    if (!name || !email || !password) {
      return fail(400, { error: 'All fields are required', name, email });
    }

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      yield* auth.signup({ name, email, password }, request.headers);
    });

    const exit = await runEffectExit(program);

    if (Exit.isSuccess(exit)) {
      redirect(307, '/');
    }

    const error = getFailure(exit);
    if (error instanceof WhitelistError) {
      return fail(400, { error: error.message, name, email });
    }
    if (error instanceof AuthError) {
      return fail(400, { error: error.message, name, email });
    }

    return fail(500, { error: 'An unexpected error occurred', name, email });
  },
};
