import { Effect, Redacted } from 'effect';
import { Config } from './Config';

const encoder = new TextEncoder();
const LIVE_SESSION_TTL_SECONDS = 5 * 60;

const base64Url = (value: Uint8Array | string) => {
  const text = typeof value === 'string' ? value : String.fromCharCode(...value);
  return btoa(text).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
};

export class LiveSession extends Effect.Service<LiveSession>()('app/LiveSession', {
  effect: Effect.gen(function* () {
    const config = yield* Config;

    const mint = (userId: string) =>
      Effect.gen(function* () {
        const issuedAt = Math.floor(Date.now() / 1000);
        const header = base64Url(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
        const payload = base64Url(
          JSON.stringify({
            sub: userId,
            exp: issuedAt + LIVE_SESSION_TTL_SECONDS,
            aud: 'datalk-live',
            iss: 'datalk',
          }),
        );
        const key = yield* Effect.promise(() =>
          crypto.subtle.importKey(
            'raw',
            encoder.encode(Redacted.value(config.celldAuthSecret)),
            { name: 'HMAC', hash: 'SHA-256' },
            false,
            ['sign'],
          ),
        );
        const signature = yield* Effect.promise(() =>
          crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${payload}`)),
        );
        return {
          token: `${header}.${payload}.${base64Url(new Uint8Array(signature))}`,
          expiresAt: issuedAt + LIVE_SESSION_TTL_SECONDS,
        };
      });

    return { mint } as const;
  }),
  dependencies: [Config.Default],
}) {}

export const LiveSessionLive = LiveSession.Default;
