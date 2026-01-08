import { Effect, Layer, Option, Duration, Scope, Context } from 'effect';
import { Persistence } from '@effect/experimental';
import { eq, and } from 'drizzle-orm';
import { Database } from './Database';
import * as T from '$lib/server/db/schema';

// ============================================================================
// BackingPersistence Implementation
// ============================================================================

/**
 * Creates a BackingPersistenceStore for a given storeId.
 * This implements the key-value interface required by @effect/ai Chat.Persisted.
 */
const makeStore = (
  storeId: string,
  db: Context.Tag.Service<typeof Database>,
): Effect.Effect<Persistence.BackingPersistenceStore, never, Scope.Scope> =>
  Effect.gen(function* () {
    // Add a finalizer for the scope (no-op for our PostgreSQL implementation)
    yield* Effect.addFinalizer(() => Effect.void);

    const get = (
      key: string,
    ): Effect.Effect<Option.Option<unknown>, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logInfo(`[ChatPersistence.get] Getting history for ${key}`);
        const result = yield* Effect.tryPromise({
          try: async () => {
            const r = await db.query.chatHistory.findFirst({
              where: and(eq(T.chatHistory.chatId, key), eq(T.chatHistory.storeId, storeId)),
            });
            return r;
          },
          catch: (error) =>
            new Persistence.PersistenceBackingError({
              reason: 'BackingError',
              method: 'get',
              cause: error,
            }),
        });
        yield* Effect.logInfo(
          `[ChatPersistence.get] Got result: ${result ? 'found' : 'not found'}`,
        );
        // The @effect/ai Chat expects a JSON string, not a parsed object
        // So we need to stringify the JSONB value we stored
        return result ? Option.some(JSON.stringify(result.history)) : Option.none();
      });

    const getMany = (
      keys: Array<string>,
    ): Effect.Effect<Array<Option.Option<unknown>>, Persistence.PersistenceError> =>
      Effect.all(keys.map(get), { concurrency: 'unbounded' });

    const set = (
      key: string,
      value: unknown,
      _ttl: Option.Option<Duration.Duration>,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logInfo(`[ChatPersistence.set] Saving history for ${key}`);
        yield* Effect.tryPromise({
          try: async () => {
            await db
              .insert(T.chatHistory)
              .values({
                chatId: key,
                storeId,
                history: value,
                updatedAt: new Date(),
              })
              .onConflictDoUpdate({
                target: [T.chatHistory.chatId, T.chatHistory.storeId],
                set: {
                  history: value,
                  updatedAt: new Date(),
                },
              });
          },
          catch: (error) =>
            new Persistence.PersistenceBackingError({
              reason: 'BackingError',
              method: 'set',
              cause: error,
            }),
        });
        yield* Effect.logInfo(`[ChatPersistence.set] Saved successfully`);
      });

    const setMany = (
      entries: ReadonlyArray<
        readonly [key: string, value: unknown, ttl: Option.Option<Duration.Duration>]
      >,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.all(
        entries.map(([key, value, ttl]) => set(key, value, ttl)),
        { concurrency: 'unbounded', discard: true },
      );

    const remove = (key: string): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.tryPromise({
        try: async () => {
          await db
            .delete(T.chatHistory)
            .where(and(eq(T.chatHistory.chatId, key), eq(T.chatHistory.storeId, storeId)));
        },
        catch: (error) =>
          new Persistence.PersistenceBackingError({
            reason: 'BackingError',
            method: 'remove',
            cause: error,
          }),
      });

    const clear: Effect.Effect<void, Persistence.PersistenceError> = Effect.tryPromise({
      try: async () => {
        await db.delete(T.chatHistory).where(eq(T.chatHistory.storeId, storeId));
      },
      catch: (error) =>
        new Persistence.PersistenceBackingError({
          reason: 'BackingError',
          method: 'clear',
          cause: error,
        }),
    });

    return {
      get,
      getMany,
      set,
      setMany,
      remove,
      clear,
    };
  });

// ============================================================================
// BackingPersistence Service
// ============================================================================

/**
 * BackingPersistence implementation using PostgreSQL.
 * This is used by @effect/ai Chat.Persisted to store conversation history.
 */
export const ChatBackingPersistenceLive = Layer.effect(
  Persistence.BackingPersistence,
  Effect.gen(function* () {
    // Capture the database at layer construction time
    const db = yield* Database;

    return {
      [Persistence.BackingPersistenceTypeId]: Persistence.BackingPersistenceTypeId,
      make: (storeId: string) => makeStore(storeId, db),
    } as Persistence.BackingPersistence;
  }),
);
