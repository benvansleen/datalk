import { Effect } from 'effect';
import { HttpError } from '../types';
import type { StoredChatSnapshot } from '../cell/shared';
import { InternalApi, InternalApiLive } from './InternalApi';

const KEY_NEXT_SEQUENCE = 'projection-next-sequence';
const KEY_OUTBOX = 'projection-outbox';
const KEY_ATTEMPT = 'projection-attempt';

type ProjectionEvent = { sequence: number };

export class Projection extends Effect.Service<Projection>()('app/Projection', {
  effect: Effect.gen(function* () {
    const internalApi = yield* InternalApi;

    const enqueueProjection = (state: DurableObjectState, snapshot: StoredChatSnapshot) =>
      Effect.gen(function* () {
        const nextSequence =
          ((yield* Effect.promise(() => state.storage.get<number>(KEY_NEXT_SEQUENCE))) ?? 0) + 1;
        const outbox =
          (yield* Effect.promise(() => state.storage.get<unknown[]>(KEY_OUTBOX))) ?? [];
        outbox.push({
          sequence: nextSequence,
          type: 'chat-snapshot',
          occurredAt: Date.now(),
          snapshot,
        });
        yield* Effect.promise(() => state.storage.put(KEY_NEXT_SEQUENCE, nextSequence));
        yield* Effect.promise(() => state.storage.put(KEY_OUTBOX, outbox));
        yield* Effect.promise(() => state.storage.setAlarm(Date.now()));
      });

    const flushProjection = (state: DurableObjectState) =>
      Effect.gen(function* () {
        const outbox =
          (yield* Effect.promise(() => state.storage.get<ProjectionEvent[]>(KEY_OUTBOX))) ?? [];
        if (outbox.length === 0) return;
        const snapshot = yield* Effect.promise(() =>
          state.storage.get<StoredChatSnapshot>('snapshot'),
        );
        const body = JSON.stringify({
          cellKind: 'chat',
          cellId: snapshot?.id,
          events: outbox.slice(0, 100),
        });
        yield* internalApi.project(body).pipe(
          Effect.matchEffect({
            onSuccess: (result) =>
              Effect.gen(function* () {
                const remaining = outbox.filter(
                  (event) => event.sequence > result.acknowledgedSequence,
                );
                yield* Effect.promise(() => state.storage.put(KEY_OUTBOX, remaining));
                yield* Effect.promise(() => state.storage.put(KEY_ATTEMPT, 0));
                if (remaining.length > 0)
                  yield* Effect.promise(() => state.storage.setAlarm(Date.now()));
              }),
            onFailure: (error) =>
              Effect.gen(function* () {
                const attempt =
                  ((yield* Effect.promise(() => state.storage.get<number>(KEY_ATTEMPT))) ?? 0) + 1;
                yield* Effect.promise(() => state.storage.put(KEY_ATTEMPT, attempt));
                yield* Effect.sync(() =>
                  console.error('Projection failed', {
                    attempt,
                    cellId: snapshot?.id,
                    firstSequence: outbox[0]?.sequence,
                    lastSequence: outbox.at(-1)?.sequence,
                    status: error instanceof HttpError ? error.status : undefined,
                    message:
                      error instanceof HttpError ? error.message : 'Unexpected projection error',
                  }),
                );
                yield* Effect.promise(() =>
                  state.storage.setAlarm(Date.now() + Math.min(60_000, 1_000 * 2 ** attempt)),
                );
              }),
          }),
        );
      });

    return { enqueueProjection, flushProjection } as const;
  }),
  dependencies: [InternalApiLive],
}) {}

export const ProjectionLive = Projection.Default;
