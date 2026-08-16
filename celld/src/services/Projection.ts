import { Console, Effect, Option } from 'effect';
import { HttpError } from '../types';
import { CellStorage } from './CellStorage';
import {
  KEY_PROJECTION_ATTEMPT,
  KEY_PROJECTION_OUTBOX,
  type StoredProjectionEvent,
} from './ChatSnapshotStore';
import { InternalApi, InternalApiLive } from './InternalApi';

export class Projection extends Effect.Service<Projection>()('app/Projection', {
  effect: Effect.gen(function* () {
    const internalApi = yield* InternalApi;
    const shouldSetAlarm = (current: Option.Option<number>, scheduledTime: number) =>
      current.pipe(
        Option.match({
          onNone: () => true,
          onSome: (currentTime) => currentTime > scheduledTime,
        }),
      );

    const flushProjection = () =>
      Effect.gen(function* () {
        const storage = yield* CellStorage;
        const outbox = Option.getOrElse(
          yield* storage.get<StoredProjectionEvent[]>(KEY_PROJECTION_OUTBOX),
          () => [],
        );
        if (outbox.length === 0) return;
        const cellId = outbox[0]!.snapshot.id;
        const body = JSON.stringify({
          cellKind: 'chat',
          cellId,
          events: outbox.slice(0, 100),
        });
        yield* internalApi.project(body).pipe(
          Effect.matchEffect({
            onSuccess: (result) =>
              storage.transaction((transaction) =>
                Effect.gen(function* () {
                  const current = Option.getOrElse(
                    yield* transaction.get<StoredProjectionEvent[]>(KEY_PROJECTION_OUTBOX),
                    () => [],
                  );
                  const remaining = current.filter(
                    (event) => event.sequence > result.acknowledgedSequence,
                  );
                  yield* transaction.put(KEY_PROJECTION_OUTBOX, remaining);
                  yield* transaction.put(KEY_PROJECTION_ATTEMPT, 0);
                  if (remaining.length > 0) yield* transaction.setAlarm(Date.now());
                }),
              ),
            onFailure: (error) =>
              Effect.gen(function* () {
                const attempt = yield* storage.transaction((transaction) =>
                  Effect.gen(function* () {
                    const nextAttempt =
                      Option.getOrElse(
                        yield* transaction.get<number>(KEY_PROJECTION_ATTEMPT),
                        () => 0,
                      ) + 1;
                    yield* transaction.put(KEY_PROJECTION_ATTEMPT, nextAttempt);
                    const retryAt = Date.now() + Math.min(60_000, 1_000 * 2 ** nextAttempt);
                    const currentAlarm = yield* transaction.getAlarm();
                    if (shouldSetAlarm(currentAlarm, retryAt)) {
                      yield* transaction.setAlarm(retryAt);
                    }
                    return nextAttempt;
                  }),
                );
                yield* Console.error('Projection failed', {
                  attempt,
                  cellId,
                  firstSequence: outbox[0]!.sequence,
                  lastSequence: outbox.at(-1)!.sequence,
                  ...(error instanceof HttpError ? { status: error.status } : {}),
                  message:
                    error instanceof HttpError ? error.message : 'Unexpected projection error',
                });
              }),
          }),
        );
      });

    return { flushProjection } as const;
  }),
  dependencies: [InternalApiLive],
}) {}

export const ProjectionLive = Projection.Default;
