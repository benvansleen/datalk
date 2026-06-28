import { svelteKitHandler } from 'better-auth/svelte-kit';
import { building } from '$app/environment';
import { redirect, type Handle, type HandleServerError } from '@sveltejs/kit';
import { Auth, AuthError, runEffectExit, requestSpanFromRequest } from '$lib/server';
import { Cause, Effect, Exit, Option } from 'effect';

const UNPROTECTED_ROUTES = ['/login', '/signup'];

export const handle: Handle = async ({ event, resolve }) => {
  const isUnprotectedRoute = UNPROTECTED_ROUTES.includes(event.url.pathname);

  return Exit.match(
    await runEffectExit(
      Effect.gen(function* () {
        const auth = yield* Auth;

        const session = isUnprotectedRoute
          ? yield* auth.getSession(event.request.headers).pipe(
              Effect.catchAllCause((cause) =>
                Effect.logWarning('Session lookup failed on unprotected route', Cause.pretty(cause)).pipe(
                  Effect.as(Option.none()),
                ),
              ),
            )
          : yield* auth.getSession(event.request.headers);
        if (Option.isSome(session)) {
          event.locals.user = session.value.user;
        } else if (!isUnprotectedRoute) {
          return yield* Effect.fail(new AuthError({ message: 'Unauthenticated user' }));
        }

        return svelteKitHandler({ event, resolve, auth: auth.__raw, building });
      }).pipe(Effect.withSpan('Handle')),
      requestSpanFromRequest(event.request, event.url, event.route?.id ?? event.url.pathname),
    ),
    {
      onSuccess: (response) => response,
      onFailure: (cause) => {
        console.error(Cause.pretty(cause));
        return redirect(303, '/login');
      },
    },
  );
};

export const handleError: HandleServerError = ({ error }) => {
  console.error(`Uncaught exception: ${JSON.stringify(error)}`);
};
