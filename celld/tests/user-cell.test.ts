import { describe, expect, it, vi } from 'vitest';
import { UserCell } from '../src/cell/user-cell';
import type { Env } from '../src/types';

const makeCell = () => {
  const values = new Map<string, unknown>([
    ['hydrated', true],
    ['chats', []],
  ]);
  const storage = {
    get: vi.fn(async <A>(key: string) => values.get(key) as A | undefined),
    put: vi.fn(async (key: string, value: unknown) => {
      values.set(key, value);
    }),
    getAlarm: vi.fn(async () => null),
    setAlarm: vi.fn(async () => undefined),
  } as {
    get: ReturnType<typeof vi.fn>;
    put: ReturnType<typeof vi.fn>;
    getAlarm: ReturnType<typeof vi.fn>;
    setAlarm: ReturnType<typeof vi.fn>;
    transaction: ReturnType<typeof vi.fn>;
  };
  storage.transaction = vi.fn(async (operation) => operation(storage));
  const state = {
    storage,
    waitUntil: vi.fn(),
    getWebSockets: vi.fn(() => []),
  } as unknown as DurableObjectState;
  const env = {
    INTERNAL_CELL_SECRET: 'internal-secret',
    INTERNAL_API_URL: 'https://datalk.internal',
    INTERNAL_PROJECTION_SECRET: 'projection-secret',
    PYTHON_SERVER_URL: 'https://python.internal',
    LIVE_ORIGIN: 'https://datalk.test',
  } as Env;
  return { cell: new UserCell(state, env), values };
};

const request = (body: string) =>
  new Request('https://cell.test/chat-status', {
    method: 'PATCH',
    headers: {
      'content-type': 'application/json',
      'x-datalk-internal-secret': 'internal-secret',
      'x-datalk-user-id': 'user-1',
    },
    body,
  });

describe('UserCell service', () => {
  it('returns a typed bad request response for invalid chat status', async () => {
    const { cell } = makeCell();

    const response = await cell.fetch(request('{'));

    expect(response.status).toBe(400);
  });

  it('transactionally stores a valid chat status', async () => {
    const { cell, values } = makeCell();
    const summary = {
      id: 'chat-1',
      dataset: 'dataset-1',
      title: 'A chat',
      updatedAt: 10,
      generating: false,
    };

    const response = await cell.fetch(request(JSON.stringify(summary)));

    expect(response.status).toBe(204);
    expect(values.get('chats')).toEqual([summary]);
  });
});
