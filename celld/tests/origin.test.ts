import type { IncomingRequestCfProperties } from '@cloudflare/workers-types';
import { afterEach, describe, expect, it, vi } from 'vitest';
import worker from '../src/index';
import type { Env } from '../src/types';

const makeEnv = () =>
  ({
    INTERNAL_CELL_SECRET: 'internal-secret',
    INTERNAL_API_URL: 'http://datalk.internal',
    INTERNAL_PROJECTION_SECRET: 'projection-secret',
    PYTHON_SERVER_URL: 'http://python.internal',
    LIVE_ORIGIN: 'http://localhost:8080',
    USER_CELL: {
      idFromName: vi.fn(() => ({})) as unknown as () => unknown,
      get: vi.fn(),
    } as unknown as DurableObjectNamespace,
    CHAT_CELL: {
      idFromName: vi.fn(() => ({})) as unknown as () => unknown,
      get: vi.fn(),
    } as unknown as DurableObjectNamespace,
  }) as Env;

const dispatch = (method: string, path: string, origin?: string) =>
  worker.fetch(
    new Request(`http://localhost:8080${path}`, {
      method,
      headers: origin ? { origin } : {},
    }) as unknown as Request<unknown, IncomingRequestCfProperties<unknown>>,
    makeEnv(),
  );

describe('live origin gate', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('accepts GETs without an Origin header', async () => {
    const response = await dispatch('GET', '/live/chats/chat-1/images/img-1');
    expect(response.status).not.toBe(403);
  });

  it('accepts HEADs without an Origin header', async () => {
    const response = await dispatch('HEAD', '/live/chats/chat-1');
    expect(response.status).not.toBe(403);
  });

  it('rejects GETs with a mismatched Origin', async () => {
    const response = await dispatch('GET', '/live/chats/chat-1', 'https://evil.example');
    expect(response.status).toBe(403);
  });

  it('rejects state-changing requests without an Origin header', async () => {
    const response = await dispatch('POST', '/live/chats');
    expect(response.status).toBe(403);
  });

  it('accepts requests whose Origin matches LIVE_ORIGIN', async () => {
    const response = await dispatch('POST', '/live/chats', 'http://localhost:8080');
    expect(response.status).not.toBe(403);
  });
});
