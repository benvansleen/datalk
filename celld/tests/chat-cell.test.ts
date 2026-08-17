import { afterEach, describe, expect, it, vi } from 'vitest';
import { ChatCell } from '../src/cell/chat-cell';
import { KEY_SNAPSHOT, type StoredChatSnapshot } from '../src/cell/shared';
import type { Env } from '../src/types';

const makeSnapshot = (): StoredChatSnapshot => ({
  id: 'chat-1',
  userId: 'user-1',
  dataset: 'dataset-1',
  title: 'Existing chat',
  deleted: false,
  generation: { status: 'pending', requestId: 'request-1' },
  createdAt: 1,
  updatedAt: 1,
  messages: [{ id: 'request-1', role: 'user', content: 'Hello', createdAt: 1 }],
  events: [],
});

const makeCell = (snapshot: StoredChatSnapshot | null = makeSnapshot()) => {
  const values = new Map<string, unknown>(snapshot ? [[KEY_SNAPSHOT, snapshot]] : []);
  const work: Promise<unknown>[] = [];
  let alarm: number | null = null;
  const storage = {
    get: vi.fn(async <T>(key: string) => values.get(key) as T | undefined),
    put: vi.fn(async (key: string, value: unknown) => {
      values.set(key, value);
    }),
    getAlarm: vi.fn(async () => alarm),
    setAlarm: vi.fn(async (scheduledTime: number) => {
      alarm = scheduledTime;
    }),
  } as {
    get: ReturnType<typeof vi.fn>;
    put: ReturnType<typeof vi.fn>;
    getAlarm: ReturnType<typeof vi.fn>;
    setAlarm: ReturnType<typeof vi.fn>;
    transaction: ReturnType<typeof vi.fn>;
  };
  storage.transaction = vi.fn(async (callback) => callback(storage));
  const state = {
    storage,
    waitUntil: vi.fn((promise: Promise<unknown>) => {
      work.push(promise);
    }),
    getWebSockets: vi.fn(() => []),
  } as unknown as DurableObjectState;
  const userCell = { fetch: vi.fn(async () => new Response(null, { status: 204 })) };
  const env = {
    INTERNAL_CELL_SECRET: 'internal-secret',
    INTERNAL_API_URL: 'https://datalk.internal',
    INTERNAL_PROJECTION_SECRET: 'projection-secret',
    PYTHON_SERVER_URL: 'https://python.internal',
    LIVE_ORIGIN: 'https://datalk.test',
    USER_CELL: {
      idFromName: vi.fn(() => ({}) as DurableObjectId),
      get: vi.fn(() => userCell),
    } as unknown as DurableObjectNamespace,
  } as Env;
  const drainWork = async () => {
    while (work.length > 0) {
      await Promise.all(work.splice(0));
    }
  };

  return {
    cell: new ChatCell(state, env),
    drainWork,
    snapshot: () => values.get(KEY_SNAPSHOT) as StoredChatSnapshot,
  };
};

describe('ChatCell generation recovery', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('does not rewrite or start an existing chat during repeated initialization', async () => {
    const { cell, drainWork, snapshot } = makeCell();
    const request = new Request('https://cell.test/initialize', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': 'user-1',
      },
      body: JSON.stringify({ chatId: 'chat-1', dataset: 'dataset-1' }),
    });

    const response = await cell.fetch(request);
    await drainWork();

    expect(response.status).toBe(200);
    expect(snapshot().generation).toEqual({ status: 'pending', requestId: 'request-1' });
    expect(snapshot().events).toEqual([]);
  });

  it('prewarms a new chat environment without delaying initialization', async () => {
    let completePrewarm: (response: Response) => void = () => undefined;
    const fetchMock = vi.fn<(input: RequestInfo | URL, init?: RequestInit) => Promise<Response>>(
      () =>
        new Promise<Response>((resolve) => {
          completePrewarm = resolve;
        }),
    );
    vi.stubGlobal('fetch', fetchMock);
    const { cell, drainWork, snapshot } = makeCell(null);
    const request = new Request('https://cell.test/initialize', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': 'user-1',
      },
      body: JSON.stringify({ chatId: 'chat-new', dataset: 'dataset-1' }),
    });

    const response = await cell.fetch(request);
    await vi.waitFor(() => expect(fetchMock).toHaveBeenCalledOnce());

    expect(response.status).toBe(200);
    expect(snapshot()).toMatchObject({ id: 'chat-new', dataset: 'dataset-1' });
    const [sentUrl, sentInit] = fetchMock.mock.calls[0];
    expect(String(sentUrl)).toBe('https://python.internal/environment/create');
    expect(sentInit).toMatchObject({
      method: 'POST',
      body: JSON.stringify({ chat_id: 'chat-new', dataset: 'dataset-1' }),
    });

    completePrewarm(Response.json({ available_dataframes: '[]' }));
    await drainWork();
  });

  it('resumes persisted generation after an isolate is replaced', async () => {
    const { cell, drainWork, snapshot } = makeCell();

    await cell.alarm();
    await drainWork();

    expect(snapshot().generation).toEqual({ status: 'idle' });
    expect(snapshot().messages.at(-1)).toMatchObject({
      role: 'assistant',
      content: "I couldn't generate a response. Please try again.",
    });
  });

  it('does not start duplicate generation for concurrent alarms', async () => {
    const { cell, drainWork, snapshot } = makeCell();

    await Promise.all([cell.alarm(), cell.alarm()]);
    await drainWork();

    expect(snapshot().events.filter((event) => event.type === 'response_done')).toHaveLength(1);
    expect(snapshot().messages.filter((message) => message.role === 'assistant')).toHaveLength(1);
  });

  it('adds a terminal fallback after a partial response fails', async () => {
    const partial = makeSnapshot();
    partial.messages.push({
      id: 'assistant-1',
      role: 'assistant',
      content: 'Let me check that.',
      createdAt: 2,
    });
    const { cell, drainWork, snapshot } = makeCell(partial);

    await cell.alarm();
    await drainWork();

    expect(snapshot().messages.at(-1)).toMatchObject({
      role: 'assistant',
      content: "I couldn't generate a response. Please try again.",
    });
  });

  it('resumes persisted generation when the chat receives a request', async () => {
    const { cell, drainWork, snapshot } = makeCell();
    const request = new Request('https://cell.test/snapshot', {
      headers: {
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': 'user-1',
      },
    });

    const response = await cell.fetch(request);
    await drainWork();

    expect(response.status).toBe(200);
    expect(snapshot().generation).toEqual({ status: 'idle' });
  });

  it('waits for an unexpired lease and exposes only derived generation fields', async () => {
    const running = makeSnapshot();
    running.generation = {
      status: 'running',
      requestId: 'request-1',
      leaseId: 'lease-1',
      leaseExpiresAt: Date.now() + 60_000,
    };
    const { cell, drainWork, snapshot } = makeCell(running);
    const request = new Request('https://cell.test/snapshot', {
      headers: {
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': 'user-1',
      },
    });

    const response = await cell.fetch(request);
    const body = (await response.json()) as Record<string, unknown>;
    await drainWork();

    expect(snapshot().generation).toEqual(running.generation);
    expect(snapshot().events).toEqual([]);
    expect(body).toMatchObject({ generating: true, currentMessageRequestId: 'request-1' });
    expect(body).not.toHaveProperty('generation');
  });

  it('cancels without starting generation when an in-flight chat is deleted', async () => {
    const { cell, drainWork, snapshot } = makeCell();
    const request = new Request('https://cell.test/', {
      method: 'DELETE',
      headers: {
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': 'user-1',
      },
    });

    const response = await cell.fetch(request);
    await drainWork();

    expect(response.status).toBe(204);
    expect(snapshot()).toMatchObject({ deleted: true, generation: { status: 'idle' } });
    expect(snapshot().events.some((event) => event.type === 'response_done')).toBe(false);
    expect(snapshot().messages).toHaveLength(1);
  });
});
