import { Effect } from 'effect';
import { describe, expect, it, vi } from 'vitest';
import { Router, RouterLive } from '../src/services/Router';
import type { Env } from '../src/types';

const makeNamespace = (fetch: ReturnType<typeof vi.fn>) =>
  ({
    idFromName: vi.fn((name: string) => name),
    get: vi.fn(() => ({ fetch })),
  }) as unknown as DurableObjectNamespace;

const makeEnv = (userFetch: ReturnType<typeof vi.fn>, chatFetch: ReturnType<typeof vi.fn>) =>
  ({
    INTERNAL_CELL_SECRET: 'internal-secret',
    USER_CELL: makeNamespace(userFetch),
    CHAT_CELL: makeNamespace(chatFetch),
  }) as Env;

const routeEffect = (request: Request, env: Env) =>
  Effect.gen(function* () {
    const router = yield* Router;
    return yield* router.route(request, new URL(request.url), env, 'user-1');
  }).pipe(Effect.provide(RouterLive));

const route = (request: Request, env: Env) => routeEffect(request, env).pipe(Effect.runPromise);

describe('Router', () => {
  it('dispatches path parameters through HttpRouter', async () => {
    const userFetch = vi.fn();
    const chatFetch = vi.fn().mockResolvedValue(new Response(null, { status: 202 }));
    const env = makeEnv(userFetch, chatFetch);

    const response = await route(
      new Request('https://datalk.test/live/chats/chat-1/messages', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ content: 'Hello' }),
      }),
      env,
    );

    expect(response.status).toBe(202);
    expect(env.CHAT_CELL.idFromName).toHaveBeenCalledWith('chat-1');
    expect(chatFetch).toHaveBeenCalledWith(
      'https://cell/messages',
      expect.objectContaining({ method: 'POST', body: JSON.stringify({ content: 'Hello' }) }),
    );
  });

  it('preserves the native response returned for WebSocket upgrades', async () => {
    const upstream = new Response(null, { status: 200 });
    const userFetch = vi.fn().mockResolvedValue(upstream);
    const env = makeEnv(userFetch, vi.fn());

    const response = await route(
      new Request('https://datalk.test/live/socket', {
        headers: { upgrade: 'websocket' },
      }),
      env,
    );

    expect(response).toBe(upstream);
    expect(userFetch).toHaveBeenCalledWith(
      'https://cell/socket',
      expect.objectContaining({ headers: expect.objectContaining({ upgrade: 'websocket' }) }),
    );
  });

  it('returns a typed not-found error for method mismatches', async () => {
    const env = makeEnv(vi.fn(), vi.fn());

    const result = await routeEffect(
      new Request('https://datalk.test/live/chats', { method: 'GET' }),
      env,
    ).pipe(Effect.either, Effect.runPromise);

    expect(result).toMatchObject({
      _tag: 'Left',
      left: expect.objectContaining({ status: 404, message: 'Not found' }),
    });
  });

  it('proxies chat image requests with both path parameters', async () => {
    const chatFetch = vi
      .fn()
      .mockResolvedValue(
        new Response(new Uint8Array([1, 2, 3]), { headers: { 'content-type': 'image/png' } }),
      );
    const env = makeEnv(vi.fn(), chatFetch);

    const response = await route(
      new Request('https://datalk.test/live/chats/chat-1/images/img-9'),
      env,
    );

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toBe('image/png');
    expect(env.CHAT_CELL.idFromName).toHaveBeenCalledWith('chat-1');
    expect(chatFetch).toHaveBeenCalledWith(
      'https://cell/images/img-9',
      expect.objectContaining({
        headers: expect.objectContaining({ 'x-datalk-chat-id': 'chat-1' }),
      }),
    );
  });
});
