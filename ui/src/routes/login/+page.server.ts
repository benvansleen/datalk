import type { Actions, PageServerLoad } from './$types';
import { redirect, fail } from '@sveltejs/kit';
import { Effect, Exit } from 'effect';
import { runEffectExit, getFailure } from '$lib/server/effect';
import { Auth } from '$lib/server/effect/services/Auth';
import { AuthError } from '$lib/server/effect/errors';

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
    const email = formData.get('email') as string;
    const password = formData.get('password') as string;

    if (!email || !password) {
      return fail(400, { error: 'Email and password are required', email });
    }

    const program = Effect.gen(function* () {
      const auth = yield* Auth;
      yield* auth.login({ email, password }, request.headers);
    });

    const exit = await runEffectExit(program);

    if (Exit.isSuccess(exit)) {
      redirect(303, '/');
    }

    const error = getFailure(exit);
    if (error instanceof AuthError) {
      return fail(400, { error: error.message, email });
    }

    return fail(500, { error: 'An unexpected error occurred', email });
  },
};
