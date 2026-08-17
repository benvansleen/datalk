import { Console, Effect, Layer, ManagedRuntime, Match, Option, Ref } from 'effect';
import { LiveLayer } from '../layers/Live';
import {
  KEY_CHAT_ID,
  emptySnapshot,
  externalSnapshotOf,
  internalHeaders,
  isInternalRequest,
  jsonHeaders,
  summaryOf,
  transitionGeneration,
  type StoredChatSnapshot,
} from '../cell/shared';
import { InitializeCommand, SubmitMessageCommand, type Env, type GenerationEvent } from '../types';
import { Agent, GenerationSink, type GenerationSinkShape } from './Agent';
import { CellPlatform, makeCellPlatformLayer } from './CellPlatform';
import { CellStorage } from './CellStorage';
import { ChatSnapshotStore, makeChatStorageLayer, type StoredImage } from './ChatSnapshotStore';
import { Environment } from './Environment';
import { Http } from './Http';
import { InternalApi } from './InternalApi';
import { Observability } from './Observability';
import { Projection } from './Projection';
import { PythonServer } from './PythonServer';

const MAX_EVENTS = 1_000;
const GENERATION_LEASE_MS = 60_000;
const GENERATION_RENEW_MS = 15_000;
const GENERATION_FALLBACK = "I couldn't generate a response. Please try again.";

type GenerationLease = { requestId: string; leaseId: string };

type GenerationRuntimeState = {
  running: boolean;
  driveRequested: boolean;
  activeLease: Option.Option<GenerationLease>;
};

type ClaimResult =
  | { _tag: 'None' }
  | { _tag: 'Waiting'; leaseExpiresAt: number }
  | {
      _tag: 'Claimed';
      snapshot: StoredChatSnapshot;
      requestId: string;
      leaseId: string;
    };

type DriveAction = { _tag: 'Maintain'; lease: Option.Option<GenerationLease> } | { _tag: 'Start' };

export class ChatCellService extends Effect.Service<ChatCellService>()('app/ChatCellService', {
  effect: Effect.gen(function* () {
    const env = yield* Environment;
    const storage = yield* CellStorage;
    const snapshots = yield* ChatSnapshotStore;
    const platform = yield* CellPlatform;
    const http = yield* Http;
    const internalApi = yield* InternalApi;
    const projection = yield* Projection;
    const pythonServer = yield* PythonServer;
    const agent = yield* Agent;
    const observability = yield* Observability;
    const generationRuntime = yield* Ref.make<GenerationRuntimeState>({
      running: false,
      driveRequested: false,
      activeLease: Option.none(),
    });
    const leaseSemaphore = yield* Effect.makeSemaphore(1);

    const shouldSetAlarm = (current: Option.Option<number>, scheduledTime: number) =>
      current.pipe(
        Option.match({
          onNone: () => true,
          onSome: (currentTime) => currentTime > scheduledTime,
        }),
      );

    const appendEvent = (
      snapshot: StoredChatSnapshot,
      type: string,
      data: unknown,
    ): GenerationEvent => {
      const event = {
        sequence: (snapshot.events.at(-1)?.sequence ?? 0) + 1,
        type,
        data,
        createdAt: Date.now(),
      };
      snapshot.events = [...snapshot.events, event].slice(-MAX_EVENTS);
      return event;
    };

    const scheduleAlarm = (scheduledTime: number) =>
      Effect.gen(function* () {
        const currentAlarm = yield* storage.getAlarm();
        if (shouldSetAlarm(currentAlarm, scheduledTime)) {
          yield* storage.setAlarm(scheduledTime);
        }
      });

    const announceSnapshot = (snapshot: StoredChatSnapshot) =>
      Effect.gen(function* () {
        const notify = Effect.tryPromise(() => {
          const user = env.USER_CELL.get(env.USER_CELL.idFromName(snapshot.userId));
          return user.fetch('https://user-cell/chat-status', {
            method: 'PATCH',
            headers: internalHeaders(env, snapshot.userId),
            body: JSON.stringify(summaryOf(snapshot)),
          });
        }).pipe(
          Effect.asVoid,
          Effect.catchAll(() => Console.error('User cell notification failed')),
        );
        yield* platform.fork(notify);
        yield* platform.broadcast({ type: 'snapshot', data: externalSnapshotOf(snapshot) });
      });

    const save = (snapshot: StoredChatSnapshot) =>
      Effect.gen(function* () {
        snapshot.updatedAt = Date.now();
        yield* snapshots.putProjected(snapshot);
        yield* announceSnapshot(snapshot);
      });

    const prewarmEnvironment = (snapshot: StoredChatSnapshot) =>
      pythonServer
        .createEnvironment(snapshot.id, snapshot.dataset)
        .pipe(Effect.catchAll(() => Console.error('Environment prewarm failed')));

    const saveGenerationSnapshot = (snapshot: StoredChatSnapshot, leaseId: string) =>
      snapshots
        .transaction((current, transaction) =>
          current.pipe(
            Option.filter((stored) => !stored.deleted && stored.generation.status === 'running'),
            Option.flatMap((stored) => {
              const now = Date.now();
              return Option.fromNullable(
                transitionGeneration(stored.generation, {
                  type: 'renew',
                  leaseId,
                  leaseExpiresAt: now + GENERATION_LEASE_MS,
                  now,
                }),
              ).pipe(Option.map((generation) => ({ stored, generation, now })));
            }),
            Effect.transposeMapOption(({ stored, generation, now }) =>
              Effect.gen(function* () {
                snapshot.generation = generation;
                snapshot.title = stored.title;
                snapshot.updatedAt = now;
                yield* transaction.putProjected(snapshot);
                const renewalAt = now + GENERATION_RENEW_MS;
                const currentAlarm = yield* transaction.getAlarm();
                if (shouldSetAlarm(currentAlarm, renewalAt)) {
                  yield* transaction.setAlarm(renewalAt);
                }
              }),
            ),
            Effect.map(Option.isSome),
          ),
        )
        .pipe(
          Effect.flatMap((committed) =>
            announceSnapshot(snapshot).pipe(
              Effect.when(() => committed),
              Effect.asVoid,
            ),
          ),
        );

    const completeGeneration = (snapshot: StoredChatSnapshot, leaseId: string) =>
      snapshots
        .transaction((current, transaction) =>
          current.pipe(
            Option.filter((stored) => !stored.deleted && stored.generation.status === 'running'),
            Option.flatMap((stored) =>
              Option.fromNullable(
                transitionGeneration(stored.generation, {
                  type: 'complete',
                  leaseId,
                  now: Date.now(),
                }),
              ).pipe(Option.map((generation) => ({ stored, generation }))),
            ),
            Effect.transposeMapOption(({ stored, generation }) => {
              snapshot.generation = generation;
              snapshot.title = stored.title;
              snapshot.updatedAt = Date.now();
              return transaction.putProjected(snapshot);
            }),
            Effect.map(Option.isSome),
          ),
        )
        .pipe(
          Effect.flatMap((committed) =>
            announceSnapshot(snapshot).pipe(
              Effect.when(() => committed),
              Effect.asVoid,
            ),
          ),
        );

    const renewGenerationLease = (lease: GenerationLease) =>
      snapshots
        .transaction((snapshot, transaction) =>
          snapshot.pipe(
            Option.filter(
              (stored) =>
                !stored.deleted &&
                stored.generation.status === 'running' &&
                stored.generation.requestId === lease.requestId,
            ),
            Option.flatMap((stored) => {
              const now = Date.now();
              return Option.fromNullable(
                transitionGeneration(stored.generation, {
                  type: 'renew',
                  leaseId: lease.leaseId,
                  leaseExpiresAt: now + GENERATION_LEASE_MS,
                  now,
                }),
              ).pipe(Option.map((generation) => ({ stored, generation, now })));
            }),
            Effect.transposeMapOption(({ stored, generation, now }) =>
              Effect.gen(function* () {
                stored.generation = generation;
                yield* transaction.put(stored);
                const renewalAt = now + GENERATION_RENEW_MS;
                const currentAlarm = yield* transaction.getAlarm();
                if (shouldSetAlarm(currentAlarm, renewalAt)) {
                  yield* transaction.setAlarm(renewalAt);
                }
              }),
            ),
            Effect.map(Option.isSome),
          ),
        )
        .pipe(
          Effect.flatMap((renewed) =>
            scheduleAlarm(Date.now() + (renewed ? GENERATION_RENEW_MS : 1_000)),
          ),
        );

    const saveTitle = (source: StoredChatSnapshot) =>
      snapshots
        .transaction((current, transaction) =>
          current.pipe(
            Option.filter(
              (snapshot) => !snapshot.deleted && snapshot.title === '...' && source.title !== '...',
            ),
            Effect.transposeMapOption((snapshot) => {
              snapshot.title = source.title;
              snapshot.updatedAt = Date.now();
              return transaction.putProjected(snapshot).pipe(Effect.as(snapshot));
            }),
          ),
        )
        .pipe(Effect.flatMap(Effect.transposeMapOption(announceSnapshot)));

    const generate = (snapshot: StoredChatSnapshot, messageRequestId: string, leaseId: string) => {
      const sink: GenerationSinkShape = {
        append: (type, data) => Effect.sync(() => appendEvent(snapshot, type, data)),
        emit: (type, data) =>
          Effect.gen(function* () {
            const event = appendEvent(snapshot, type, data);
            yield* platform.broadcast({ type: 'event', data: event });
          }),
        save: () => saveGenerationSnapshot(snapshot, leaseId).pipe(Effect.orDie),
        saveTitle: () => saveTitle(snapshot).pipe(Effect.orDie),
        spawn: (work) => platform.fork(work),
        saveImages: (images) =>
          snapshots
            .saveImages(images)
            .pipe(
              Effect.catchAll((error) =>
                Console.error(`Image persistence failed: ${String(error.cause)}`).pipe(
                  Effect.as([]),
                ),
              ),
            ),
      };
      const generation = observability.track(
        'app.chat.generation',
        agent
          .runGeneration(snapshot, messageRequestId)
          .pipe(Effect.provideService(GenerationSink, sink)),
      );
      const finalize = Effect.gen(function* () {
        yield* Ref.update(generationRuntime, (state) => ({
          ...state,
          activeLease: Option.none(),
        }));
        yield* leaseSemaphore.withPermits(1)(Effect.void);
        const userMessageIndex = snapshot.messages.findIndex(
          (message) => message.id === messageRequestId && message.role === 'user',
        );
        const hasVisibleAssistantResponse =
          userMessageIndex !== -1 &&
          snapshot.messages
            .slice(userMessageIndex + 1)
            .some((message) => message.role === 'assistant' && message.content.trim().length > 0);
        const generationStartedIndex = snapshot.events.findLastIndex(
          (event) => event.type === 'generation-started',
        );
        const generationFailed = snapshot.events
          .slice(generationStartedIndex + 1)
          .some((event) => event.type === 'response_error');
        if (!hasVisibleAssistantResponse || generationFailed) {
          snapshot.messages.push({
            id: crypto.randomUUID(),
            role: 'assistant',
            content: GENERATION_FALLBACK,
            createdAt: Date.now(),
          });
        }
        yield* completeGeneration(snapshot, leaseId);
      });
      return generation.pipe(Effect.ensuring(finalize.pipe(Effect.orDie)));
    };

    const advanceGeneration = Effect.suspend(() => {
      const now = Date.now();
      const leaseId = crypto.randomUUID();
      return snapshots
        .transaction((snapshot, transaction) =>
          Option.match(snapshot, {
            onNone: () => Effect.succeed({ _tag: 'None' } as ClaimResult),
            onSome: (stored) =>
              Effect.gen(function* () {
                if (stored.deleted || stored.generation.status === 'idle') {
                  return { _tag: 'None' } as ClaimResult;
                }
                if (
                  stored.generation.status === 'running' &&
                  stored.generation.leaseExpiresAt > now
                ) {
                  return {
                    _tag: 'Waiting',
                    leaseExpiresAt: stored.generation.leaseExpiresAt,
                  } as ClaimResult;
                }
                const generation = transitionGeneration(stored.generation, {
                  type: 'claim',
                  leaseId,
                  leaseExpiresAt: now + GENERATION_LEASE_MS,
                  now,
                });
                if (!generation || generation.status !== 'running') {
                  return { _tag: 'None' } as ClaimResult;
                }
                stored.generation = generation;
                stored.updatedAt = now;
                yield* transaction.putProjected(stored);
                const renewalAt = now + GENERATION_RENEW_MS;
                const currentAlarm = yield* transaction.getAlarm();
                if (shouldSetAlarm(currentAlarm, renewalAt)) {
                  yield* transaction.setAlarm(renewalAt);
                }
                return {
                  _tag: 'Claimed',
                  snapshot: stored,
                  requestId: generation.requestId,
                  leaseId,
                } as ClaimResult;
              }),
          }),
        )
        .pipe(
          Effect.flatMap((result) =>
            Match.value(result).pipe(
              Match.when({ _tag: 'None' }, () => Effect.void),
              Match.when({ _tag: 'Waiting' }, ({ leaseExpiresAt }) =>
                scheduleAlarm(leaseExpiresAt),
              ),
              Match.when({ _tag: 'Claimed' }, (claimed) =>
                Ref.update(generationRuntime, (state) => ({
                  ...state,
                  activeLease: Option.some({
                    requestId: claimed.requestId,
                    leaseId: claimed.leaseId,
                  }),
                })).pipe(
                  Effect.andThen(announceSnapshot(claimed.snapshot)),
                  Effect.andThen(scheduleAlarm(now + GENERATION_RENEW_MS)),
                  Effect.andThen(generate(claimed.snapshot, claimed.requestId, claimed.leaseId)),
                ),
              ),
              Match.exhaustive,
            ),
          ),
        );
    });

    const driveGeneration: Effect.Effect<void> = Effect.suspend(() =>
      Ref.modify(generationRuntime, (state): readonly [DriveAction, GenerationRuntimeState] =>
        state.running
          ? [
              { _tag: 'Maintain', lease: state.activeLease },
              { ...state, driveRequested: true },
            ]
          : [{ _tag: 'Start' }, { ...state, running: true, driveRequested: false }],
      ).pipe(
        Effect.flatMap((action) => {
          const maintain = (lease: Option.Option<GenerationLease>) =>
            Effect.transposeMapOption(lease, (activeLease) =>
              platform.fork(
                leaseSemaphore
                  .withPermits(1)(renewGenerationLease(activeLease))
                  .pipe(
                    Effect.catchAll(() =>
                      Console.error('Generation lease renewal failed').pipe(
                        Effect.andThen(scheduleAlarm(Date.now() + 1_000)),
                      ),
                    ),
                  ),
              ),
            );
          const start = () => {
            const finish = Ref.modify(generationRuntime, (state) => [
              state.driveRequested,
              { ...state, running: false, activeLease: Option.none(), driveRequested: false },
            ]).pipe(
              Effect.flatMap((rerun) =>
                driveGeneration.pipe(
                  Effect.when(() => rerun),
                  Effect.asVoid,
                ),
              ),
            );
            return platform.fork(
              advanceGeneration.pipe(
                Effect.catchAll(() => scheduleAlarm(Date.now() + 1_000)),
                Effect.ensuring(finish),
              ),
            );
          };
          return Match.value(action).pipe(
            Match.when({ _tag: 'Maintain' }, ({ lease }) => maintain(lease)),
            Match.when({ _tag: 'Start' }, start),
            Match.exhaustive,
          );
        }),
      ),
    );

    const hydrate = (userId: string) =>
      storage
        .get<string>(KEY_CHAT_ID)
        .pipe(
          Effect.flatMap(
            Effect.transposeMapOption((chatId) => internalApi.hydrateChat(chatId, userId)),
          ),
          Effect.map(Option.flatten),
          Effect.flatMap(
            Effect.transposeMapOption((hydrated) => snapshots.putHydratedIfAbsent(hydrated)),
          ),
        );

    const initialize = (request: Request, userId: string) =>
      http.decodeJson(request, InitializeCommand).pipe(
        Effect.flatMap(({ chatId, dataset }) =>
          snapshots.load.pipe(
            Effect.flatMap((existing) => {
              const snapshot = Option.getOrElse(existing, () =>
                emptySnapshot(chatId, userId, dataset),
              );
              if (snapshot.userId !== userId) {
                return Effect.succeed(Response.json({ error: 'Forbidden' }, { status: 403 }));
              }
              return storage.put(KEY_CHAT_ID, chatId).pipe(
                Effect.andThen(
                  save(snapshot).pipe(
                    Effect.andThen(platform.fork(prewarmEnvironment(snapshot))),
                    Effect.when(() => Option.isNone(existing)),
                  ),
                ),
                Effect.as(Response.json(summaryOf(snapshot), { headers: jsonHeaders })),
              );
            }),
          ),
        ),
        Effect.catchTag('HttpError', () =>
          Effect.succeed(
            Response.json({ error: 'chatId and dataset are required' }, { status: 400 }),
          ),
        ),
      );

    const deleteChat = (snapshot: StoredChatSnapshot) =>
      Effect.gen(function* () {
        snapshot.deleted = true;
        snapshot.generation = transitionGeneration(snapshot.generation, { type: 'cancel' })!;
        appendEvent(snapshot, 'chat-deleted', { chatId: snapshot.id });
        yield* save(snapshot);
        return new Response(null, { status: 204 });
      });

    const submitMessage = (request: Request, snapshot: StoredChatSnapshot) =>
      http.decodeJson(request, SubmitMessageCommand).pipe(
        Effect.flatMap(({ content }) => {
          if (snapshot.generation.status !== 'idle') {
            return Effect.succeed(
              Response.json({ error: 'Already generating a response' }, { status: 409 }),
            );
          }
          const requestId = crypto.randomUUID();
          snapshot.generation = transitionGeneration(snapshot.generation, {
            type: 'submit',
            requestId,
          })!;
          snapshot.messages.push({
            id: requestId,
            role: 'user',
            content,
            createdAt: Date.now(),
          });
          appendEvent(snapshot, 'message-submitted', {
            messageRequestId: requestId,
            content,
          });
          appendEvent(snapshot, 'generation-started', { messageRequestId: requestId });
          return save(snapshot).pipe(
            Effect.andThen(driveGeneration),
            Effect.as(
              Response.json({ messageRequestId: requestId }, { status: 202, headers: jsonHeaders }),
            ),
          );
        }),
        Effect.catchTag('HttpError', () =>
          Effect.succeed(
            Response.json(
              { error: 'content must be between 1 and 32000 characters' },
              { status: 400 },
            ),
          ),
        ),
      );

    const serveImage = (imageId: string): Effect.Effect<Response> =>
      snapshots.getImage(imageId).pipe(
        Effect.flatMap(
          Effect.transposeMapOption((image: StoredImage) =>
            Effect.succeed(
              new Response(image.bytes, {
                headers: {
                  'content-type': image.mime,
                  'cache-control': 'private, max-age=31536000, immutable',
                  'x-content-type-options': 'nosniff',
                },
              }),
            ),
          ),
        ),
        Effect.map(Option.getOrElse(() => new Response(null, { status: 404 }))),
        Effect.catchAll(() => Effect.succeed(new Response(null, { status: 404 }))),
      );

    const routeSnapshot = (
      request: Request,
      url: URL,
      userId: string,
      snapshot: StoredChatSnapshot,
    ) => {
      if (snapshot.userId !== userId) {
        return Effect.succeed(Response.json({ error: 'Forbidden' }, { status: 403 }));
      }
      if (snapshot.deleted) {
        return Effect.succeed(Response.json({ error: 'Chat was deleted' }, { status: 404 }));
      }
      const resume = driveGeneration.pipe(
        Effect.unless(() => snapshot.generation.status === 'idle'),
        Effect.asVoid,
      );
      return Match.value({ method: request.method, path: url.pathname }).pipe(
        Match.when({ method: 'DELETE', path: '/' }, () => deleteChat(snapshot)),
        Match.orElse((route) =>
          resume.pipe(
            Effect.andThen(
              Match.value(route).pipe(
                Match.when({ method: 'GET', path: '/snapshot' }, () =>
                  Effect.succeed(
                    Response.json(externalSnapshotOf(snapshot), { headers: jsonHeaders }),
                  ),
                ),
                Match.when({ method: 'GET', path: '/socket' }, () =>
                  platform.upgrade(externalSnapshotOf(snapshot)),
                ),
                Match.when({ method: 'POST', path: '/messages' }, () =>
                  submitMessage(request, snapshot),
                ),
                Match.when(
                  (route: { method: string; path: string }) =>
                    route.method === 'GET' && route.path.startsWith('/images/'),
                  (route) => serveImage(route.path.slice('/images/'.length)),
                ),
                Match.orElse(() =>
                  Effect.succeed(Response.json({ error: 'Not found' }, { status: 404 })),
                ),
              ),
            ),
          ),
        ),
      );
    };

    const fetchForUser = (request: Request, userId: string) => {
      const url = new URL(request.url);
      return Match.value({ method: request.method, path: url.pathname }).pipe(
        Match.when({ method: 'POST', path: '/initialize' }, () => initialize(request, userId)),
        Match.orElse(() => {
          const requestedChatId = Option.fromNullable(request.headers.get('x-datalk-chat-id'));
          return Effect.transposeMapOption(requestedChatId, (chatId) =>
            storage.put(KEY_CHAT_ID, chatId),
          ).pipe(
            Effect.andThen(snapshots.load),
            Effect.flatMap(
              Option.match({
                onNone: () => hydrate(userId),
                onSome: (snapshot) => Effect.succeed(Option.some(snapshot)),
              }),
            ),
            Effect.flatMap(
              Option.match({
                onNone: () =>
                  Effect.succeed(
                    Response.json({ error: 'Chat is not initialized' }, { status: 404 }),
                  ),
                onSome: (snapshot) => routeSnapshot(request, url, userId, snapshot),
              }),
            ),
          );
        }),
      );
    };

    const fetch = (request: Request) =>
      Effect.if(isInternalRequest(request, env), {
        onTrue: () =>
          Option.match(Option.fromNullable(request.headers.get('x-datalk-user-id')), {
            onNone: () =>
              Effect.succeed(Response.json({ error: 'Missing user identity' }, { status: 400 })),
            onSome: (userId) => fetchForUser(request, userId),
          }),
        onFalse: () => Effect.succeed(Response.json({ error: 'Forbidden' }, { status: 403 })),
      });

    const alarm = snapshots.load.pipe(
      Effect.flatMap(
        Effect.transposeMapOption((snapshot) =>
          Effect.when(
            driveGeneration,
            () => !snapshot.deleted && snapshot.generation.status !== 'idle',
          ),
        ),
      ),
      Effect.andThen(
        projection.flushProjection().pipe(Effect.provideService(CellStorage, storage)),
      ),
    );

    return {
      fetch,
      alarm,
      webSocketMessage: platform.webSocketMessage,
      webSocketClose: platform.webSocketClose,
    } as const;
  }),
}) {}

export const makeChatCellRuntime = (
  state: DurableObjectState,
  env: Env,
): ManagedRuntime.ManagedRuntime<ChatCellService, never> => {
  const environment = Layer.succeed(Environment, env);
  const app = LiveLayer.pipe(Layer.provide(environment));
  const storage = makeChatStorageLayer(state.storage);
  const platform = makeCellPlatformLayer(state);
  const dependencies = Layer.mergeAll(environment, app, storage, platform);
  return ManagedRuntime.make(ChatCellService.Default.pipe(Layer.provide(dependencies)));
};
