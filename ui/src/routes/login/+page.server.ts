import type { Actions, PageServerLoad } from './$types';
import { redirect, fail } from '@sveltejs/kit';
import { Effect, Exit, Cause } from 'effect';
import { Auth, AuthError, runEffectExit } from '$lib/server';

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

    return Exit.match(
      await runEffectExit(
        Effect.gen(function* () {
          const auth = yield* Auth;
          yield* auth.login({ email, password }, request.headers);
        }),
      ),
      {
        onSuccess: () => redirect(303, '/'),
        onFailure: (cause) => {
          if (Cause.isFailType(cause) && cause.error instanceof AuthError) {
            return fail(400, { error: cause.error.message, email });
          }
          return fail(500, { error: 'An unexpected error occurred', email });
        },
      },
    );
  },
};
