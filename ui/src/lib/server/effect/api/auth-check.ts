import { Effect, Option } from 'effect';
import type { User } from 'better-auth';
import type { RequestEvent } from '@sveltejs/kit';
import { AuthError } from '../errors';

/**
 * Effect-based authentication check for use in server endpoints.
 * Returns the authenticated user or fails with AuthError.
 */
export const requireAuthEffect = (event: RequestEvent) =>
  Effect.gen(function* () {
    const user = event.locals.user;
    if (!user) {
      return yield* Effect.fail(new AuthError({ message: 'Authentication required' }));
    }
    return user;
  }).pipe(Effect.withSpan('auth.requireAuth'));

/**
 * Effect-based authentication check that returns Option<User>.
 * Use when you want to handle unauthenticated users gracefully.
 */
export const getAuthEffect = (event: RequestEvent) =>
  Effect.succeed(Option.fromNullable(event.locals.user)).pipe(
    Effect.withSpan('auth.getAuth')
  );

/**
 * Check if a user owns a specific resource.
 * Fails with AuthError if not authorized.
 */
export const requireOwnership = <T extends { userId: string }>(
  user: User,
  resource: T | null | undefined,
  resourceName = 'resource'
) =>
  Effect.gen(function* () {
    if (!resource) {
      return yield* Effect.fail(
        new AuthError({ message: `${resourceName} not found` })
      );
    }
    if (resource.userId !== user.id) {
      return yield* Effect.fail(
        new AuthError({ message: `Not authorized to access this ${resourceName}` })
      );
    }
    return resource;
  }).pipe(Effect.withSpan('auth.requireOwnership'));
