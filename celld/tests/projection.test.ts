import { Effect } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { externalSnapshotOf, type StoredChatSnapshot } from '../src/cell/shared';
import { ChatSnapshotStore, makeChatStorageLayer } from '../src/services/ChatSnapshotStore';
import { Projection } from '../src/services/Projection';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const env = {
  INTERNAL_API_URL: 'http://datalk.internal',
  INTERNAL_PROJECTION_SECRET: 'projection-secret',
} as Env;

const snapshot: StoredChatSnapshot = {
  id: 'chat-1',
  userId: 'user-1',
  dataset: 'dataset-1',
  title: 'A chat',
  deleted: false,
  generation: { status: 'idle' },
  createdAt: 1,
  updatedAt: 1,
  messages: [],
  events: [],
};

const projectionEvent = (sequence: number) => ({
  sequence,
  type: 'chat-snapshot' as const,
  occurredAt: 1,
  snapshot: externalSnapshotOf(snapshot),
});

const makeState = (initial: Record<string, unknown> = {}, initialAlarm: number | null = null) => {
  const values = new Map<string, unknown>(Object.entries(initial));
  let alarm = initialAlarm;
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
  return { values, storage, state: { storage } as unknown as DurableObjectState };
};

const enqueue = (state: DurableObjectState) =>
  runWithEnv(
    env,
    Effect.gen(function* () {
      const snapshots = yield* ChatSnapshotStore;
      return yield* snapshots.putProjected(snapshot);
    }).pipe(Effect.provide(makeChatStorageLayer(state.storage))),
  );

const flush = (state: DurableObjectState) =>
  runWithEnv(
    env,
    Effect.gen(function* () {
      const projection = yield* Projection;
      return yield* projection.flushProjection();
    }).pipe(Effect.provide(makeChatStorageLayer(state.storage))),
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
      expect.objectContaining({
        sequence: 1,
        type: 'chat-snapshot',
        snapshot: expect.objectContaining({
          id: snapshot.id,
          generating: false,
          currentMessageRequestId: null,
        }),
      }),
      expect.objectContaining({
        sequence: 2,
        type: 'chat-snapshot',
        snapshot: expect.objectContaining({
          id: snapshot.id,
          generating: false,
          currentMessageRequestId: null,
        }),
      }),
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
      'projection-outbox': [projectionEvent(1), projectionEvent(2), projectionEvent(3)],
      'projection-attempt': 4,
    });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([projectionEvent(3)]);
    expect(values.get('projection-attempt')).toBe(0);
    expect(storage.setAlarm).toHaveBeenCalledTimes(1);
  });

  it('retains projections enqueued while a batch is being delivered', async () => {
    let resolveProjection!: (response: Response) => void;
    vi.stubGlobal(
      'fetch',
      vi.fn(
        () =>
          new Promise<Response>((resolve) => {
            resolveProjection = resolve;
          }),
      ),
    );
    const { values, state } = makeState({
      'projection-next-sequence': 1,
      'projection-outbox': [projectionEvent(1)],
    });

    const flushing = flush(state);
    await vi.waitFor(() => expect(resolveProjection).toBeTypeOf('function'));
    await enqueue(state);
    resolveProjection(Response.json({ acknowledgedSequence: 1 }));
    await flushing;

    expect(values.get('projection-outbox')).toEqual([
      expect.objectContaining({ sequence: 2, type: 'chat-snapshot' }),
    ]);
  });

  it('empties the outbox without a retry when everything is acknowledged', async () => {
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(Response.json({ acknowledgedSequence: 3 })));
    const { values, storage, state } = makeState({
      'projection-outbox': [projectionEvent(1), projectionEvent(2), projectionEvent(3)],
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
      'projection-outbox': Array.from({ length: 150 }, (_, index) => projectionEvent(index + 1)),
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
      'projection-outbox': [projectionEvent(4)],
    });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([projectionEvent(4)]);
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
    const { values, state } = makeState({ 'projection-outbox': [projectionEvent(4)] });

    await flush(state);

    expect(values.get('projection-outbox')).toEqual([projectionEvent(4)]);
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
      'projection-outbox': [projectionEvent(1)],
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
      'projection-outbox': [projectionEvent(1)],
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

  it('does not postpone an earlier generation alarm when projection fails', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue(Response.json({ error: 'boom' }, { status: 500 })),
    );
    vi.spyOn(console, 'error').mockImplementation(() => undefined);
    const generationAlarm = Date.now() + 5_000;
    const { storage, state } = makeState(
      { 'projection-outbox': [projectionEvent(1)], 'projection-attempt': 9 },
      generationAlarm,
    );

    await flush(state);

    expect(storage.setAlarm).not.toHaveBeenCalled();
    expect(await storage.getAlarm()).toBe(generationAlarm);
  });
});
