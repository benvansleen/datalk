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

      return { load, put, putProjected, putHydratedIfAbsent, transaction } as const;
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
