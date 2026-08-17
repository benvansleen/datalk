import { Cause, Context, Data, Effect, Exit, Layer, Option } from 'effect';

export class CellStorageError extends Data.TaggedError('CellStorageError')<{
  operation: string;
  cause: unknown;
}> {}

export type CellStorageTransaction = {
  get: <A>(key: string) => Effect.Effect<Option.Option<A>, CellStorageError>;
  put: (key: string, value: unknown) => Effect.Effect<void, CellStorageError>;
  getAlarm: () => Effect.Effect<Option.Option<number>, CellStorageError>;
  setAlarm: (scheduledTime: number) => Effect.Effect<void, CellStorageError>;
};

type CellStorageShape = CellStorageTransaction & {
  transaction: <A>(
    operation: (transaction: CellStorageTransaction) => Effect.Effect<A, CellStorageError>,
  ) => Effect.Effect<A, CellStorageError>;
};

const storageError = (operation: string, cause: unknown) =>
  cause instanceof CellStorageError ? cause : new CellStorageError({ operation, cause });

const makeStorageOperations = (
  storage: DurableObjectStorage | DurableObjectTransaction,
): CellStorageTransaction => ({
  get: <A>(key: string) =>
    Effect.tryPromise({
      try: () => storage.get<A>(key),
      catch: (cause) => storageError('get', cause),
    }).pipe(Effect.map(Option.fromNullable)),
  put: (key: string, value: unknown) =>
    Effect.tryPromise({
      try: () => storage.put(key, value),
      catch: (cause) => storageError('put', cause),
    }),
  getAlarm: () =>
    Effect.tryPromise({
      try: () => storage.getAlarm(),
      catch: (cause) => storageError('getAlarm', cause),
    }).pipe(Effect.map(Option.fromNullable)),
  setAlarm: (scheduledTime: number) =>
    Effect.tryPromise({
      try: () => storage.setAlarm(scheduledTime),
      catch: (cause) => storageError('setAlarm', cause),
    }),
});

class TransactionEffectFailure {
  constructor(readonly cause: Cause.Cause<CellStorageError>) {}
}

const makeCellStorage = (storage: DurableObjectStorage): CellStorageShape => ({
  ...makeStorageOperations(storage),
  transaction: <A>(
    operation: (transaction: CellStorageTransaction) => Effect.Effect<A, CellStorageError>,
  ) =>
    Effect.async<A, CellStorageError>((resume, signal) => {
      void storage
        .transaction(async (transaction) => {
          const exit = await Effect.runPromiseExit(operation(makeStorageOperations(transaction)), {
            signal,
          });
          if (Exit.isFailure(exit)) throw new TransactionEffectFailure(exit.cause);
          return exit.value;
        })
        .then(
          (value) => resume(Effect.succeed(value)),
          (cause) =>
            resume(
              cause instanceof TransactionEffectFailure
                ? Effect.failCause(cause.cause)
                : Effect.fail(storageError('transaction', cause)),
            ),
        );
    }),
});

class CellStorageBackend extends Context.Tag('app/CellStorageBackend')<
  CellStorageBackend,
  DurableObjectStorage
>() {}

export class CellStorage extends Effect.Service<CellStorage>()('app/CellStorage', {
  effect: Effect.map(CellStorageBackend, makeCellStorage),
}) {}

export const makeCellStorageLayer = (storage: DurableObjectStorage): Layer.Layer<CellStorage> =>
  CellStorage.Default.pipe(Layer.provide(Layer.succeed(CellStorageBackend, storage)));
