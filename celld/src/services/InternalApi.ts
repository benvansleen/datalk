import { Effect, Redacted, Schema } from 'effect';
import { HttpError } from '../types';
import { Config, ConfigLive } from './Config';

const encoder = new TextEncoder();

const base64UrlEncode = (value: Uint8Array): string =>
  btoa(String.fromCharCode(...value))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');

const sha256 = (value: string): Effect.Effect<Uint8Array> =>
  Effect.promise(() =>
    crypto.subtle.digest('SHA-256', encoder.encode(value)).then((digest) => new Uint8Array(digest)),
  );

const hmacSha256 = (secret: string, message: string): Effect.Effect<Uint8Array> =>
  Effect.promise(() =>
    crypto.subtle
      .importKey('raw', encoder.encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'])
      .then((key) =>
        crypto.subtle
          .sign('HMAC', key, encoder.encode(message))
          .then((signature) => new Uint8Array(signature)),
      ),
  );

const internalSignature = (
  secret: string,
  method: string,
  pathname: string,
  body: string,
  timestamp: string,
): Effect.Effect<string> =>
  Effect.gen(function* () {
    const digest = yield* sha256(body);
    const signature = yield* hmacSha256(
      secret,
      `${timestamp}\n${method}\n${pathname}\n${base64UrlEncode(digest)}`,
    );
    return base64UrlEncode(signature);
  });

const ProjectionResponse = Schema.Struct({ acknowledgedSequence: Schema.Number });

const VerifySessionResponse = Schema.Struct({
  userId: Schema.String,
  expiresAt: Schema.Number,
});

export class InternalApi extends Effect.Service<InternalApi>()('app/InternalApi', {
  effect: Effect.gen(function* () {
    const config = yield* Config;

    const signedRequest = (method: string, path: string, body = '') =>
      Effect.gen(function* () {
        const timestamp = String(Date.now());
        const signature = yield* internalSignature(
          Redacted.value(config.internalProjectionSecret),
          method,
          path,
          body,
          timestamp,
        );
        return new Request(new URL(path, config.internalApiUrl), {
          method,
          headers: {
            'content-type': 'application/json',
            'x-datalk-internal-timestamp': timestamp,
            'x-datalk-internal-signature': signature,
          },
          ...(body ? { body } : {}),
        });
      });

    const fetchInternal = (
      path: string,
      init: { method?: string; body?: string },
      unavailableMessage: string,
    ) =>
      Effect.gen(function* () {
        const request = yield* signedRequest(init.method ?? 'GET', path, init.body ?? '');
        return yield* Effect.tryPromise({
          try: () => fetch(request),
          catch: () => new HttpError({ status: 503, message: unavailableMessage }),
        });
      });

    const project = (body: string) =>
      Effect.gen(function* () {
        const response = yield* fetchInternal(
          '/api/internal/cells/project',
          { method: 'POST', body },
          'Projection service is unavailable',
        );
        if (!response.ok) {
          const detail = (yield* Effect.tryPromise({
            try: () => response.text(),
            catch: () => Promise.resolve(''),
          })).slice(0, 500);
          return yield* Effect.fail(
            new HttpError({
              status: response.status,
              message: detail ? `Projection was rejected: ${detail}` : 'Projection was rejected',
            }),
          );
        }
        const json = yield* Effect.tryPromise({
          try: () => response.json(),
          catch: () => new HttpError({ status: 502, message: 'Invalid projection response' }),
        });
        return yield* Schema.decodeUnknown(ProjectionResponse)(json).pipe(
          Effect.mapError(
            () => new HttpError({ status: 502, message: 'Invalid projection response' }),
          ),
        );
      });

    const verifySession = (cookie: string) =>
      Effect.gen(function* () {
        const response = yield* fetchInternal(
          '/api/internal/auth/verify-session',
          { method: 'POST', body: JSON.stringify({ cookie }) },
          'Session verification is unavailable',
        );
        if (!response.ok) {
          return yield* Effect.fail(
            new HttpError({
              status: response.status === 401 ? 401 : 502,
              message:
                response.status === 401
                  ? 'Invalid live session'
                  : 'Session verification was rejected',
            }),
          );
        }
        const json = yield* Effect.tryPromise({
          try: () => response.json(),
          catch: () =>
            new HttpError({ status: 502, message: 'Invalid session verification response' }),
        });
        return yield* Schema.decodeUnknown(VerifySessionResponse)(json).pipe(
          Effect.mapError(
            () => new HttpError({ status: 502, message: 'Invalid session verification response' }),
          ),
        );
      });

    const hydrate = (path: string) =>
      Effect.gen(function* () {
        const response = yield* fetchInternal(
          path,
          { method: 'GET' },
          'Hydration service is unavailable',
        );
        if (response.status === 404) return null;
        if (!response.ok)
          return yield* Effect.fail(
            new HttpError({ status: response.status, message: 'Hydration was rejected' }),
          );
        return yield* Effect.tryPromise({
          try: () => response.json(),
          catch: () => new HttpError({ status: 502, message: 'Invalid hydration response' }),
        });
      });

    const hydrateChat = (chatId: string, userId: string) =>
      hydrate(
        `/api/internal/cells/chats/${encodeURIComponent(chatId)}?userId=${encodeURIComponent(userId)}`,
      );

    const hydrateUser = (userId: string) =>
      hydrate(`/api/internal/cells/users/${encodeURIComponent(userId)}`);

    return { project, verifySession, hydrateChat, hydrateUser } as const;
  }),
  dependencies: [ConfigLive],
}) {}

export const InternalApiLive = InternalApi.Default;
