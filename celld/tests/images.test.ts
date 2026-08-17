import { Effect, Option } from 'effect';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { ChatCell } from '../src/cell/chat-cell';
import { KEY_SNAPSHOT, type StoredChatSnapshot } from '../src/cell/shared';
import {
  ChatSnapshotStore,
  KEY_IMAGE_INDEX,
  makeChatStorageLayer,
  type ImageRef,
} from '../src/services/ChatSnapshotStore';
import type { Env } from '../src/types';

const makeSnapshot = (): StoredChatSnapshot => ({
  id: 'chat-1',
  userId: 'user-1',
  dataset: 'dataset-1',
  title: 'Existing chat',
  deleted: false,
  generation: { status: 'idle' },
  createdAt: 1,
  updatedAt: 1,
  messages: [],
  events: [],
});

const makeStorage = () => {
  const values = new Map<string, unknown>([[KEY_SNAPSHOT, makeSnapshot()]]);
  const storage = {
    get: vi.fn(async <T>(key: string) => values.get(key) as T | undefined),
    put: vi.fn(async (key: string, value: unknown) => {
      values.set(key, value);
    }),
    delete: vi.fn(async (key: string) => {
      values.delete(key);
    }),
    getAlarm: vi.fn(async () => null),
    setAlarm: vi.fn(async () => {}),
    transaction: vi.fn(),
  };
  storage.transaction = vi.fn(async (callback: (txn: unknown) => Promise<unknown>) =>
    callback(storage),
  );
  return { storage, values };
};

const png1x1 =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

const image = (id: string) => ({ id, mime: 'image/png', data: png1x1 });

describe('ChatSnapshotStore images', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('persists images and returns references', async () => {
    const { storage, values } = makeStorage();
    const store = await Effect.runPromise(
      Effect.gen(function* () {
        const store = yield* ChatSnapshotStore;
        return yield* store.saveImages([image('img-1'), image('img-2')]);
      }).pipe(Effect.provide(makeChatStorageLayer(storage as unknown as DurableObjectStorage))),
    );

    expect(store).toEqual([
      { id: 'img-1', mime: 'image/png' },
      { id: 'img-2', mime: 'image/png' },
    ] satisfies ImageRef[]);
    expect(values.get('img:img-1')).toMatchObject({ mime: 'image/png' });
    expect(values.get(KEY_IMAGE_INDEX)).toEqual(['img-1', 'img-2']);
  });

  it('evicts the oldest images beyond the chat quota', async () => {
    const { storage, values } = makeStorage();
    const store = await Effect.runPromise(
      Effect.gen(function* () {
        const store = yield* ChatSnapshotStore;
        return yield* store.saveImages(
          Array.from({ length: 51 }, (_, index) => image(`img-${index}`)),
        );
      }).pipe(Effect.provide(makeChatStorageLayer(storage as unknown as DurableObjectStorage))),
    );

    expect(store).toHaveLength(51);
    expect(values.has('img:img-0')).toBe(false);
    expect(values.has('img:img-1')).toBe(true);
    expect(values.get(KEY_IMAGE_INDEX)).toEqual(
      Array.from({ length: 50 }, (_, i) => `img-${i + 1}`),
    );
  });

  it('returns stored bytes through getImage', async () => {
    const { storage } = makeStorage();
    const layer = makeChatStorageLayer(storage as unknown as DurableObjectStorage);
    const found = await Effect.runPromise(
      Effect.gen(function* () {
        const store = yield* ChatSnapshotStore;
        yield* store.saveImages([image('img-1')]);
        return yield* store.getImage('img-1');
      }).pipe(Effect.provide(layer)),
    );

    const bytes = new Uint8Array(
      atob(png1x1)
        .split('')
        .map((character) => character.charCodeAt(0)),
    );
    expect(Option.isSome(found)).toBe(true);
    if (Option.isSome(found)) {
      expect(found.value.mime).toBe('image/png');
      expect(Array.from(found.value.bytes)).toEqual(Array.from(bytes));
    }
  });
});

describe('ChatCell image route', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  const makeCell = () => {
    const { storage, values } = makeStorage();
    const work: Promise<unknown>[] = [];
    const state = {
      storage,
      waitUntil: vi.fn((promise: Promise<unknown>) => {
        work.push(promise);
      }),
      getWebSockets: vi.fn(() => []),
    } as unknown as DurableObjectState;
    const env = {
      INTERNAL_CELL_SECRET: 'internal-secret',
      INTERNAL_API_URL: 'https://datalk.internal',
      INTERNAL_PROJECTION_SECRET: 'projection-secret',
      PYTHON_SERVER_URL: 'https://python.internal',
      LIVE_ORIGIN: 'https://datalk.test',
      USER_CELL: {
        idFromName: vi.fn(() => ({}) as DurableObjectId),
        get: vi.fn(() => ({ fetch: vi.fn() })),
      } as unknown as DurableObjectNamespace,
    } as Env;
    return {
      cell: new ChatCell(state, env),
      values,
      storage: storage as unknown as DurableObjectStorage,
    };
  };

  const imageRequest = (path: string, userId = 'user-1') =>
    new Request(`https://cell.test${path}`, {
      headers: {
        'x-datalk-internal-secret': 'internal-secret',
        'x-datalk-user-id': userId,
      },
    });

  it('serves a stored image with content type and cache headers', async () => {
    const harness = makeCell();
    await Effect.runPromise(
      Effect.gen(function* () {
        const store = yield* ChatSnapshotStore;
        return yield* store.saveImages([image('img-1')]);
      }).pipe(Effect.provide(makeChatStorageLayer(harness.storage))),
    );

    const response = await harness.cell.fetch(imageRequest('/images/img-1'));

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toBe('image/png');
    expect(response.headers.get('cache-control')).toBe('private, max-age=31536000, immutable');
    expect(response.headers.get('x-content-type-options')).toBe('nosniff');
  });

  it('returns 404 for unknown images', async () => {
    const harness = makeCell();

    const response = await harness.cell.fetch(imageRequest('/images/missing'));

    expect(response.status).toBe(404);
  });

  it('rejects requests from other users', async () => {
    const harness = makeCell();
    await Effect.runPromise(
      Effect.gen(function* () {
        const store = yield* ChatSnapshotStore;
        return yield* store.saveImages([image('img-1')]);
      }).pipe(Effect.provide(makeChatStorageLayer(harness.storage))),
    );

    const response = await harness.cell.fetch(imageRequest('/images/img-1', 'user-2'));

    expect(response.status).toBe(403);
  });
});
