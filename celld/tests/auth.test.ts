import { Effect } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { runEffect } from '../src/runtime';
import { Auth } from '../src/services/Auth';
import type { Env } from '../src/types';

const makeEnv = () =>
  ({
    INTERNAL_API_URL: 'http://datalk.internal',
    INTERNAL_PROJECTION_SECRET: 'projection-secret',
  }) as Env;

const authenticate = (env: Env, cookie: string | undefined) =>
  runEffect(
    env,
    Effect.gen(function* () {
      const auth = yield* Auth;
      return yield* auth.authenticate(
        new Request('https://datalk.test/live/chats', {
          headers: cookie ? { cookie } : {},
        }),
      );
    }),
  );

describe('authenticate', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('verifies the forwarded session cookie against the SvelteKit service', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        Response.json({ userId: 'user-1', expiresAt: Math.floor(Date.now() / 1000) + 60 }),
      );
    vi.stubGlobal('fetch', fetchMock);

    const session = await authenticate(makeEnv(), 'better-auth.session_token=abc');

    expect(session.sub).toBe('user-1');
    const sent = fetchMock.mock.calls[0][0] as Request;
    expect(sent.url).toBe('http://datalk.internal/api/internal/auth/verify-session');
    expect(sent.method).toBe('POST');
    expect(sent.headers.get('x-datalk-internal-signature')).toBeTruthy();
    expect(JSON.parse(await sent.text())).toEqual({ cookie: 'better-auth.session_token=abc' });
  });

  it('caches a verified cookie within the isolate', async () => {
    const env = makeEnv();
    const fetchMock = vi
      .fn()
      .mockResolvedValue(
        Response.json({ userId: 'user-1', expiresAt: Math.floor(Date.now() / 1000) + 60 }),
      );
    vi.stubGlobal('fetch', fetchMock);

    const first = await authenticate(env, 'better-auth.session_token=cached');
    const second = await authenticate(env, 'better-auth.session_token=cached');

    expect(first.sub).toBe('user-1');
    expect(second.sub).toBe('user-1');
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it('rejects requests without a session cookie', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);

    await expect(authenticate(makeEnv(), undefined)).rejects.toThrow('Missing live session');
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('rejects cookies the service cannot verify', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 401 }));
    vi.stubGlobal('fetch', fetchMock);

    await expect(authenticate(makeEnv(), 'better-auth.session_token=nope')).rejects.toThrow(
      'Invalid live session',
    );
  });
});
