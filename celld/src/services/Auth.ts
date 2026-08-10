import { Effect } from 'effect';
import { HttpError } from '../types';
import { InternalApi, InternalApiLive } from './InternalApi';

const CACHE_TTL_MS = 10 * 60 * 1000;

type CachedSession = { userId: string; expiresAtMs: number };

export class Auth extends Effect.Service<Auth>()('app/Auth', {
  effect: Effect.gen(function* () {
    const internalApi = yield* InternalApi;

    const cache = new Map<string, CachedSession>();

    const authenticate = (request: Request) =>
      Effect.gen(function* () {
        const cookie = request.headers.get('cookie');
        if (!cookie)
          return yield* Effect.fail(
            new HttpError({ status: 401, message: 'Missing live session' }),
          );

        const cached = cache.get(cookie);
        if (cached && cached.expiresAtMs > Date.now()) {
          return { sub: cached.userId, exp: Math.floor(cached.expiresAtMs / 1000) };
        }

        const session = yield* internalApi.verifySession(cookie);
        const expiresAtMs = Math.min(session.expiresAt * 1000, Date.now() + CACHE_TTL_MS);
        cache.set(cookie, { userId: session.userId, expiresAtMs });
        return { sub: session.userId, exp: Math.floor(expiresAtMs / 1000) };
      });

    return { authenticate } as const;
  }),
  dependencies: [InternalApiLive],
}) {}

export const AuthLive = Auth.Default;
