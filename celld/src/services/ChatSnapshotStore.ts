import { Effect, Layer, Option } from 'effect';
import {
  KEY_SNAPSHOT,
  externalSnapshotOf,
  snapshotFromHydration,
  type ExternalChatSnapshot,
  type HydratedChatSnapshot,
  type StoredChatSnapshot,
} from '../cell/shared';
import {
  CellStorage,
  type CellStorageError,
  type CellStorageTransaction,
  makeCellStorageLayer,
} from './CellStorage';

export const KEY_PROJECTION_NEXT_SEQUENCE = 'projection-next-sequence';
export const KEY_PROJECTION_OUTBOX = 'projection-outbox';
export const KEY_PROJECTION_ATTEMPT = 'projection-attempt';
export const KEY_IMAGE_INDEX = 'image-index';

const MAX_CHAT_IMAGES = 50;

export type StoredImageInput = { id: string; mime: string; data: string };
export type StoredImage = { mime: string; bytes: Uint8Array<ArrayBuffer> };
export type ImageRef = { id: string; mime: string };

const imageKey = (id: string) => `img:${id}`;

const decodeBase64 = (data: string): Uint8Array<ArrayBuffer> => {
  const binary = atob(data);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes;
};

export type StoredProjectionEvent = {
  sequence: number;
  type: 'chat-snapshot';
  occurredAt: number;
  snapshot: ExternalChatSnapshot;
};

export type ChatSnapshotTransaction = {
  put: (snapshot: StoredChatSnapshot) => Effect.Effect<void, CellStorageError>;
  putProjected: (snapshot: StoredChatSnapshot) => Effect.Effect<void, CellStorageError>;
  getAlarm: () => Effect.Effect<Option.Option<number>, CellStorageError>;
  setAlarm: (scheduledTime: number) => Effect.Effect<void, CellStorageError>;
};

export class ChatSnapshotStore extends Effect.Service<ChatSnapshotStore>()(
  'app/ChatSnapshotStore',
  {
    effect: Effect.gen(function* () {
      const storage = yield* CellStorage;

      const load = storage.get<StoredChatSnapshot>(KEY_SNAPSHOT);

      const put = (snapshot: StoredChatSnapshot) => storage.put(KEY_SNAPSHOT, snapshot);

      const enqueueProjection = (
        transaction: CellStorageTransaction,
        snapshot: StoredChatSnapshot,
      ) =>
        Effect.gen(function* () {
          const nextSequence =
            Option.getOrElse(
              yield* transaction.get<number>(KEY_PROJECTION_NEXT_SEQUENCE),
              () => 0,
            ) + 1;
          const outbox = Option.getOrElse(
            yield* transaction.get<StoredProjectionEvent[]>(KEY_PROJECTION_OUTBOX),
            (): StoredProjectionEvent[] => [],
          );
          outbox.push({
            sequence: nextSequence,
            type: 'chat-snapshot',
            occurredAt: Date.now(),
            snapshot: externalSnapshotOf(snapshot),
          });
          yield* transaction.put(KEY_PROJECTION_NEXT_SEQUENCE, nextSequence);
          yield* transaction.put(KEY_PROJECTION_OUTBOX, outbox);
          yield* transaction.setAlarm(Date.now());
        });

      const putProjected = (snapshot: StoredChatSnapshot) =>
        storage.transaction((transaction) =>
          Effect.gen(function* () {
            yield* transaction.put(KEY_SNAPSHOT, snapshot);
            yield* enqueueProjection(transaction, snapshot);
          }),
        );

      const putHydratedIfAbsent = (snapshot: HydratedChatSnapshot) => {
        const normalized = snapshotFromHydration(snapshot);
        return storage.transaction((transaction) =>
          transaction.get<StoredChatSnapshot>(KEY_SNAPSHOT).pipe(
            Effect.flatMap(
              Option.match({
                onNone: () => transaction.put(KEY_SNAPSHOT, normalized).pipe(Effect.as(normalized)),
                onSome: Effect.succeed,
              }),
            ),
          ),
        );
      };

      const transaction = <A>(
        operation: (
          snapshot: Option.Option<StoredChatSnapshot>,
          transaction: ChatSnapshotTransaction,
        ) => Effect.Effect<A, CellStorageError>,
      ) =>
        storage.transaction((storageTransaction) =>
          storageTransaction.get<StoredChatSnapshot>(KEY_SNAPSHOT).pipe(
            Effect.flatMap((snapshot) =>
              operation(snapshot, {
                put: (nextSnapshot) => storageTransaction.put(KEY_SNAPSHOT, nextSnapshot),
                putProjected: (nextSnapshot) =>
                  Effect.gen(function* () {
                    yield* storageTransaction.put(KEY_SNAPSHOT, nextSnapshot);
                    yield* enqueueProjection(storageTransaction, nextSnapshot);
                  }),
                getAlarm: storageTransaction.getAlarm,
                setAlarm: storageTransaction.setAlarm,
              }),
            ),
          ),
        );

      const saveImages = (images: ReadonlyArray<StoredImageInput>) =>
        storage.transaction((transaction) =>
          Effect.gen(function* () {
            if (images.length === 0) return [];
            const index = Option.getOrElse(
              yield* transaction.get<string[]>(KEY_IMAGE_INDEX),
              (): string[] => [],
            );
            let ids = [...index];
            for (const image of images) {
              yield* transaction.put(imageKey(image.id), {
                mime: image.mime,
                bytes: decodeBase64(image.data),
              } satisfies StoredImage);
              ids.push(image.id);
            }
            while (ids.length > MAX_CHAT_IMAGES) {
              const evicted = ids.shift();
              if (evicted === undefined) break;
              yield* transaction.delete(imageKey(evicted));
            }
            yield* transaction.put(KEY_IMAGE_INDEX, ids);
            return images.map(({ id, mime }): ImageRef => ({ id, mime }));
          }),
        );

      const getImage = (id: string) => storage.get<StoredImage>(imageKey(id));

      return {
        load,
        put,
        putProjected,
        putHydratedIfAbsent,
        transaction,
        saveImages,
        getImage,
      } as const;
    }),
  },
) {}

export const makeChatStorageLayer = (
  storage: DurableObjectStorage,
): Layer.Layer<CellStorage | ChatSnapshotStore> => {
  const cellStorage = makeCellStorageLayer(storage);
  const snapshots = ChatSnapshotStore.Default.pipe(Layer.provide(cellStorage));
  return Layer.merge(cellStorage, snapshots);
};
