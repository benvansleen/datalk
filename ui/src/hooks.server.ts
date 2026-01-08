import { svelteKitHandler } from 'better-auth/svelte-kit';
import { building } from '$app/environment';
import { redirect, type Handle, type HandleServerError } from '@sveltejs/kit';
import { Auth, AuthError, runEffectExit } from '$lib/server';
import { Effect, Exit, Option } from 'effect';

const UNPROTECTED_ROUTES = ['/login', '/signup'];

export const handle: Handle = async ({ event, resolve }) => {
  return Exit.match(
    await runEffectExit(
      Effect.gen(function* () {
        const auth = yield* Auth;

        const session = yield* auth.getSession(event.request.headers);
        if (Option.isSome(session)) {
          event.locals.user = session.value.user;
        } else if (!UNPROTECTED_ROUTES.includes(event.url.pathname)) {
          return yield* Effect.fail(new AuthError({ message: 'Unauthenticated user' }));
        }

        return svelteKitHandler({ event, resolve, auth: auth.__raw, building });
      }).pipe(Effect.withSpan('Handle')),
    ),
    {
      onSuccess: (response) => response,
      onFailure: () => redirect(303, '/login'),
    },
  );
};

export const handleError: HandleServerError = ({ error }) => {
  console.error(`Uncaught exception: ${JSON.stringify(error)}`);
};
