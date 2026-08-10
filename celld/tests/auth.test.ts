import { Effect } from 'effect';
import { describe, expect, it } from 'vitest';
import { Auth } from '../src/services/Auth';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const encoder = new TextEncoder();

const encode = (value: string) =>
  btoa(value).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');

const sign = async (payload: object, secret = 'test-secret') => {
  const header = encode(JSON.stringify({ alg: 'HS256', typ: 'JWT' }));
  const body = encode(JSON.stringify(payload));
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(
    await crypto.subtle.sign('HMAC', key, encoder.encode(`${header}.${body}`)),
  );
  return `${header}.${body}.${encode(String.fromCharCode(...signature))}`;
};

const env = { AUTH_SECRET: 'test-secret' } as Env;

const authenticate = (token: string) =>
  runWithEnv(
    env,
    Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.authenticate(
        new Request('https://datalk.test/live/chats', {
          headers: { authorization: `Bearer ${token}` },
        }),
      );
    }),
  );

describe('authenticate', () => {
  it('accepts a current, correctly signed live session', async () => {
    const token = await sign({
      sub: 'user-1',
      exp: Math.floor(Date.now() / 1000) + 60,
      aud: 'datalk-live',
      iss: 'datalk',
    });
    const session = await authenticate(token);

    expect(session.sub).toBe('user-1');
  });

  it('rejects expired and tampered sessions', async () => {
    const expired = await sign({ sub: 'user-1', exp: 1, aud: 'datalk-live', iss: 'datalk' });
    const signatureStart = expired.lastIndexOf('.') + 1;
    const tampered = `${expired.slice(0, signatureStart)}${expired[signatureStart] === 'A' ? 'B' : 'A'}${expired.slice(signatureStart + 1)}`;

    await expect(authenticate(expired)).rejects.toThrow('Expired live session');
    await expect(authenticate(tampered)).rejects.toThrow('Invalid live session');
  });
});
