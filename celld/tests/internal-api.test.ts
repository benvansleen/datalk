import { Effect } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { InternalApi } from '../src/services/InternalApi';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const env = {
  INTERNAL_API_URL: 'http://datalk.internal',
  INTERNAL_PROJECTION_SECRET: 'projection-secret',
} as Env;

const encoder = new TextEncoder();

const base64Url = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes))
    .replaceAll('+', '-')
    .replaceAll('/', '_')
    .replaceAll('=', '');

describe('internal API client', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('signs projection requests so the server can verify them', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ acknowledgedSequence: 0 }));
    vi.stubGlobal('fetch', fetchMock);
    const body = '{"cellKind":"chat","cellId":"chat-1","events":[]}';

    await runWithEnv(
      env,
      Effect.gen(function* () {
        const api = yield* InternalApi;
        return yield* api.project(body);
      }),
    );

    const sent = fetchMock.mock.calls[0][0] as Request;
    expect(sent.url).toBe('http://datalk.internal/api/internal/cells/project');
    expect(sent.method).toBe('POST');

    const timestamp = sent.headers.get('x-datalk-internal-timestamp');
    const signature = sent.headers.get('x-datalk-internal-signature');
    expect(timestamp).toMatch(/^\d+$/);
    expect(Math.abs(Date.now() - Number(timestamp))).toBeLessThan(30_000);

    const bodyHash = base64Url(
      new Uint8Array(await crypto.subtle.digest('SHA-256', encoder.encode(body))),
    );
    const key = await crypto.subtle.importKey(
      'raw',
      encoder.encode('projection-secret'),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const expected = base64Url(
      new Uint8Array(
        await crypto.subtle.sign(
          'HMAC',
          key,
          encoder.encode(`${timestamp}\nPOST\n/api/internal/cells/project\n${bodyHash}`),
        ),
      ),
    );
    expect(signature).toBe(expected);
    expect(await sent.text()).toBe(body);
  });

  it('maps hydration 404s to null and surfaces other rejections', async () => {
    const fetchMock = vi
      .fn()
      .mockResolvedValueOnce(new Response(null, { status: 404 }))
      .mockResolvedValueOnce(Response.json({ error: 'nope' }, { status: 500 }));
    vi.stubGlobal('fetch', fetchMock);

    const missing = await runWithEnv(
      env,
      Effect.gen(function* () {
        const api = yield* InternalApi;
        return yield* api.hydrateChat('chat-1', 'user-1');
      }),
    );
    expect(missing).toBeNull();

    await expect(
      runWithEnv(
        env,
        Effect.gen(function* () {
          const api = yield* InternalApi;
          return yield* api.hydrateUser('user-1');
        }),
      ),
    ).rejects.toThrow('Hydration was rejected');

    const [first, second] = fetchMock.mock.calls.map(([request]) => (request as Request).url);
    expect(first).toBe('http://datalk.internal/api/internal/cells/chats/chat-1?userId=user-1');
    expect(second).toBe('http://datalk.internal/api/internal/cells/users/user-1');
  });
});
