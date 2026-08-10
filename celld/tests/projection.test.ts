import { Effect } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import type { StoredChatSnapshot } from '../src/cell/shared';
import { Projection } from '../src/services/Projection';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const env = {
  INTERNAL_API_URL: 'http://datalk.internal',
  INTERNAL_PROJECTION_SECRET: 'projection-secret',
} as Env;

const snapshot = { id: 'chat-1' } as unknown as StoredChatSnapshot;

const makeState = (initial: Record<string, unknown> = {}) => {
  const values = new Map<string, unknown>(Object.entries(initial));
  const storage = {
    get: vi.fn(async <T>(key: string) => values.get(key) as T | undefined),
    put: vi.fn(async (key: string, value: unknown) => {
      values.set(key, value);
    }),
    setAlarm: vi.fn(async (_alarm: number) => undefined),
  };
  return { values, storage, state: { storage } as unknown as DurableObjectState };
};

const enqueue = (state: DurableObjectState) =>
  runWithEnv(
    env,
    Effect.gen(function* () {
      const projection = yield* Projection;
      return yield* projection.enqueueProjection(state, snapshot);
    }),
  );

const flush = (state: DurableObjectState) =>
  runWithEnv(
    env,
    Effect.gen(function* () {
      const projection = yield* Projection;
      return yield* projection.flushProjection(state);
    }),
  );

describe('projection outbox', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    vi.restoreAllMocks();
  });

  it('assigns contiguous sequences and schedules an immediate flush', async () => {
    const { values, storage, state } = makeState();

    await enqueue(state);
    await enqueue(state);

    expect(values.get('projection-next-sequence')).toBe(2);
    expect(values.get('projection-outbox')).toEqual([
      expect.objectContaining({ sequence: 1, type: 'chat-snapshot', snapshot }),
      expect.objectContaining({ sequence: 2, type: 'chat-snapshot', snapshot }),
    ]);
    expect(storage.setAlarm).toHaveBeenCalledTimes(2);
  });

  it('does not call the projection API when the outbox is empty', async () => {
    const fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    const { state } = makeState();

    await flush(state);

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('trims acknowledged events, resets attempts, and retries the remainder', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ acknowledgedSequence: 2 })));
    const { values, storage, state } = makeState({
      'projection-outbox': [{ sequence: 1 }, { sequence: 2 }, { sequence: 3 }],
      'projection-attempt': 4,
    });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([{ sequence: 3 }]);
    expect(values.get('projection-attempt')).toBe(0);
    expect(storage.setAlarm).toHaveBeenCalledTimes(1);
  });

  it('empties the outbox without a retry when everything is acknowledged', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ acknowledgedSequence: 3 })));
    const { values, storage, state } = makeState({
      'projection-outbox': [{ sequence: 1 }, { sequence: 2 }, { sequence: 3 }],
    });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([]);
    expect(values.get('projection-attempt')).toBe(0);
    expect(storage.setAlarm).not.toHaveBeenCalled();
  });

  it('sends at most one hundred events per projection batch', async () => {
    const fetchMock = vi.fn().mockResolvedValue(Response.json({ acknowledgedSequence: 100 }));
    vi.stubGlobal('fetch', fetchMock);
    const { values, state } = makeState({
      snapshot: { id: 'chat-1' },
      'projection-outbox': Array.from({ length: 150 }, (_, index) => ({ sequence: index + 1 })),
    });

    await flush(state);

    const sent = fetchMock.mock.calls[0][0] as Request;
    const body = JSON.parse(await sent.text());
    expect(body.events).toHaveLength(100);
    expect(body.cellKind).toBe('chat');
    expect(body.cellId).toBe('chat-1');
    expect(values.get('projection-outbox')).toHaveLength(50);
  });

  it('retains a rejected projection and logs its sequence range', async () => {
    vi.stubGlobal(
      'fetch',
      vi
        .fn()
        .mockResolvedValue(Response.json({ error: 'Projection sequence gap' }, { status: 409 })),
    );
    const error = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const { values, state } = makeState({
      snapshot: { id: 'chat-1' },
      'projection-outbox': [{ sequence: 4 }],
    });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([{ sequence: 4 }]);
    expect(values.get('projection-attempt')).toBe(1);
    expect(error).toHaveBeenCalledWith(
      'Projection failed',
      expect.objectContaining({
        attempt: 1,
        cellId: 'chat-1',
        firstSequence: 4,
        lastSequence: 4,
        status: 409,
        message: 'Projection was rejected: {"error":"Projection sequence gap"}',
      }),
    );
  });

  it('retains the outbox when the projection service is unreachable', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new TypeError('network down')));
    const error = vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const { values, state } = makeState({ 'projection-outbox': [{ sequence: 4 }] });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([{ sequence: 4 }]);
    expect(values.get('projection-attempt')).toBe(1);
    expect(error).toHaveBeenCalledWith(
      'Projection failed',
      expect.objectContaining({ status: 503, message: 'Projection service is unavailable' }),
    );
  });

  it('grows the retry backoff exponentially', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(Response.json({ error: 'boom' }, { status: 500 })),
    );
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const { values, storage, state } = makeState({
      'projection-outbox': [{ sequence: 1 }],
      'projection-attempt': 2,
    });

    const before = Date.now();
    await flush(state);
    const after = Date.now();

    expect(values.get('projection-attempt')).toBe(3);
    const alarm = storage.setAlarm.mock.calls[0][0] as number;
    expect(alarm).toBeGreaterThanOrEqual(before + 8_000);
    expect(alarm).toBeLessThanOrEqual(after + 8_000);
  });

  it('caps the retry backoff at one minute', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(Response.json({ error: 'boom' }, { status: 500 })),
    );
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const { values, storage, state } = makeState({
      'projection-outbox': [{ sequence: 1 }],
      'projection-attempt': 9,
    });

    const before = Date.now();
    await flush(state);
    const after = Date.now();

    expect(values.get('projection-attempt')).toBe(10);
    const alarm = storage.setAlarm.mock.calls[0][0] as number;
    expect(alarm).toBeGreaterThanOrEqual(before + 60_000);
    expect(alarm).toBeLessThanOrEqual(after + 60_000);
  });
});
