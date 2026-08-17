import { Effect, Option } from 'effect';
import { describe, expect, it, vi } from 'vitest';
import type { StoredChatSnapshot } from '../src/cell/shared';
import { CellStorage, CellStorageError, makeCellStorageLayer } from '../src/services/CellStorage';
import { ChatSnapshotStore, makeChatStorageLayer } from '../src/services/ChatSnapshotStore';

const makeStorage = (initial: Record<string, unknown> = {}) => {
  const values = new Map(Object.entries(initial));
  let alarm: number | null = null;
  const storage = {
    get: vi.fn(async <A>(key: string) => values.get(key) as A | undefined),
    put: vi.fn(async (key: string, value: unknown) => {
      values.set(key, value);
    }),
    getAlarm: vi.fn(async () => alarm),
    setAlarm: vi.fn(async (scheduledTime: number) => {
      alarm = scheduledTime;
    }),
    transaction: vi.fn(async (operation) => operation(storage)),
  } as unknown as DurableObjectStorage;
  return { storage, values };
};

describe('CellStorage service', () => {
  it('runs storage and transaction operations as Effects', async () => {
    const { storage } = makeStorage();

    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const cellStorage = yield* CellStorage;
        yield* cellStorage.put('value', 1);
        yield* cellStorage.transaction((transaction) =>
          Effect.gen(function* () {
            const value = yield* transaction.get<number>('value');
            yield* transaction.put('value', Option.getOrElse(value, () => 0) + 1);
            yield* transaction.setAlarm(123);
          }),
        );
        return yield* Effect.all({
          value: cellStorage.get<number>('value'),
          alarm: cellStorage.getAlarm(),
        });
      }).pipe(Effect.provide(makeCellStorageLayer(storage))),
    );

    expect(result).toEqual({ value: Option.some(2), alarm: Option.some(123) });
  });

  it('maps storage failures to CellStorageError', async () => {
    const { storage } = makeStorage();
    vi.mocked(storage.get).mockRejectedValueOnce(new Error('unavailable'));

    const error = await Effect.runPromise(
      Effect.gen(function* () {
        const cellStorage = yield* CellStorage;
        return yield* cellStorage.get('value');
      }).pipe(Effect.provide(makeCellStorageLayer(storage)), Effect.flip),
    );

    expect(error).toMatchObject({
      _tag: 'CellStorageError',
      operation: 'get',
    });
    expect(error).toBeInstanceOf(CellStorageError);
  });

  it('preserves typed failures from transaction Effects', async () => {
    const { storage } = makeStorage();
    const expected = new CellStorageError({ operation: 'inner', cause: 'failed' });

    const error = await Effect.runPromise(
      Effect.gen(function* () {
        const cellStorage = yield* CellStorage;
        return yield* cellStorage.transaction(() => Effect.fail(expected));
      }).pipe(Effect.provide(makeCellStorageLayer(storage)), Effect.flip),
    );

    expect(error).toBe(expected);
  });
});

describe('ChatSnapshotStore service', () => {
  it('loads and transactionally updates state-machine snapshots', async () => {
    const stored: StoredChatSnapshot = {
      id: 'chat-1',
      userId: 'user-1',
      dataset: 'dataset-1',
      title: 'A chat',
      deleted: false,
      generation: { status: 'pending', requestId: 'request-1' },
      createdAt: 1,
      updatedAt: 1,
      messages: [{ id: 'request-1', role: 'user', content: 'Hello', createdAt: 1 }],
      events: [],
    };
    const { storage, values } = makeStorage({ snapshot: stored });

    const snapshot = await Effect.runPromise(
      Effect.gen(function* () {
        const snapshots = yield* ChatSnapshotStore;
        yield* snapshots.transaction((current, transaction) =>
          Effect.gen(function* () {
            if (Option.isNone(current)) return;
            current.value.title = 'Updated chat';
            yield* transaction.put(current.value);
          }),
        );
        return yield* snapshots.load;
      }).pipe(Effect.provide(makeChatStorageLayer(storage))),
    );

    const loaded = Option.getOrThrow(snapshot);
    expect(loaded).toMatchObject({
      title: 'Updated chat',
      generation: { status: 'pending', requestId: 'request-1' },
    });
    expect(values.get('snapshot')).toEqual(loaded);
  });

  it('does not overwrite a snapshot created during hydration', async () => {
    const existing: StoredChatSnapshot = {
      id: 'chat-1',
      userId: 'user-1',
      dataset: 'dataset-1',
      title: 'Current chat',
      deleted: false,
      generation: { status: 'idle' },
      createdAt: 1,
      updatedAt: 2,
      messages: [],
      events: [],
    };
    const { storage, values } = makeStorage({ snapshot: existing });

    const result = await Effect.runPromise(
      Effect.gen(function* () {
        const snapshots = yield* ChatSnapshotStore;
        return yield* snapshots.putHydratedIfAbsent({
          ...existing,
          title: 'Stale hydration',
          generating: false,
          currentMessageRequestId: null,
        });
      }).pipe(Effect.provide(makeChatStorageLayer(storage))),
    );

    expect(result.title).toBe('Current chat');
    expect(values.get('snapshot')).toEqual(existing);
  });
});
