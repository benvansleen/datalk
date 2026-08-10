import { Effect, Redacted, Schema } from 'effect';
import { HttpError, LiveSession } from '../types';
import { Config, ConfigLive } from './Config';

const encoder = new TextEncoder();

const base64UrlDecode = (value: string): Uint8Array => {
  const normalized = value.replace(/-/g, '+').replace(/_/g, '/');
  const decoded = atob(normalized.padEnd(Math.ceil(normalized.length / 4) * 4, '='));
  return Uint8Array.from(decoded, (character) => character.charCodeAt(0));
};

const equalBytes = (left: Uint8Array, right: Uint8Array): boolean => {
  if (left.byteLength !== right.byteLength) return false;
  let difference = 0;
  for (let index = 0; index < left.byteLength; index += 1) difference |= left[index] ^ right[index];
  return difference === 0;
};

const bearerToken = (request: Request): string | undefined => {
  const authorization = request.headers.get('authorization');
  if (authorization?.startsWith('Bearer ')) return authorization.slice('Bearer '.length);
  return request.headers
    .get('cookie')
    ?.split(';')
    .map((cookie) => cookie.trim().split('='))
    .find(([name]) => name === 'datalk_live')?.[1];
};

export class Auth extends Effect.Service<Auth>()('app/Auth', {
  effect: Effect.gen(function* () {
    const config = yield* Config;

    const authenticate = (request: Request) =>
      Effect.gen(function* () {
        const token = bearerToken(request);
        if (!token)
          return yield* Effect.fail(
            new HttpError({ status: 401, message: 'Missing live session' }),
          );

        const [encodedHeader, encodedPayload, encodedSignature, ...rest] = token.split('.');
        if (!encodedHeader || !encodedPayload || !encodedSignature || rest.length > 0) {
          return yield* Effect.fail(
            new HttpError({ status: 401, message: 'Invalid live session' }),
          );
        }

        const key = yield* Effect.tryPromise({
          try: () =>
            crypto.subtle.importKey(
              'raw',
              encoder.encode(Redacted.value(config.authSecret)),
              { name: 'HMAC', hash: 'SHA-256' },
              false,
              ['sign', 'verify'],
            ),
          catch: () => new HttpError({ status: 500, message: 'Unable to verify live session' }),
        });
        const valid = yield* Effect.tryPromise({
          try: async () => {
            const expected = new Uint8Array(
              await crypto.subtle.sign(
                'HMAC',
                key,
                encoder.encode(`${encodedHeader}.${encodedPayload}`),
              ),
            );
            return equalBytes(expected, base64UrlDecode(encodedSignature));
          },
          catch: () => new HttpError({ status: 401, message: 'Invalid live session' }),
        });
        if (!valid)
          return yield* Effect.fail(
            new HttpError({ status: 401, message: 'Invalid live session' }),
          );

        const payload = yield* Effect.try({
          try: () => JSON.parse(new TextDecoder().decode(base64UrlDecode(encodedPayload))),
          catch: () => new HttpError({ status: 401, message: 'Invalid live session' }),
        });
        const session = yield* Schema.decodeUnknown(LiveSession)(payload).pipe(
          Effect.mapError(() => new HttpError({ status: 401, message: 'Invalid live session' })),
        );
        if (session.exp <= Math.floor(Date.now() / 1000)) {
          return yield* Effect.fail(
            new HttpError({ status: 401, message: 'Expired live session' }),
          );
        }
        return session;
      });

    return { authenticate } as const;
  }),
  dependencies: [ConfigLive],
}) {}

export const AuthLive = Auth.Default;
