import { Effect, Layer, ManagedRuntime, Match, Option, Schema } from 'effect';
import { LiveLayer } from '../layers/Live';
import { internalHeaders, isInternalRequest, jsonHeaders } from '../cell/shared';
import {
  ChatSummary,
  CreateChatCommand,
  type ChatSummary as ChatSummaryData,
  type Env,
} from '../types';
import { CellPlatform, makeCellPlatformLayer } from './CellPlatform';
import { CellStorage, makeCellStorageLayer } from './CellStorage';
import { Environment } from './Environment';
import { Http } from './Http';
import { InternalApi } from './InternalApi';

const KEY_CHATS = 'chats';
const KEY_HYDRATED = 'hydrated';
type ChatSummaryList = ReadonlyArray<ChatSummaryData>;

export class UserCellService extends Effect.Service<UserCellService>()('app/UserCellService', {
  effect: Effect.gen(function* () {
    const env = yield* Environment;
    const storage = yield* CellStorage;
    const platform = yield* CellPlatform;
    const internalApi = yield* InternalApi;
    const http = yield* Http;

    const storedChats = (value: Option.Option<ChatSummaryList>) =>
      Option.getOrElse(value, (): ChatSummaryList => []);

    const ensureHydrated = (userId: string) => {
      const isHydrated = storage.get<boolean>(KEY_HYDRATED).pipe(Effect.map(Option.contains(true)));
      const hydrate = internalApi.hydrateUser(userId).pipe(
        Effect.catchAll(() => Effect.succeed(Option.none<ChatSummaryList>())),
        Effect.flatMap(
          Option.match({
            onNone: () => Effect.void,
            onSome: (hydrated) =>
              storage.transaction((transaction) => {
                const alreadyHydrated = transaction
                  .get<boolean>(KEY_HYDRATED)
                  .pipe(Effect.map(Option.contains(true)));
                return transaction
                  .put(KEY_CHATS, hydrated)
                  .pipe(
                    Effect.andThen(transaction.put(KEY_HYDRATED, true)),
                    Effect.unlessEffect(alreadyHydrated),
                    Effect.asVoid,
                  );
              }),
          }),
        ),
      );
      return hydrate.pipe(Effect.unlessEffect(isHydrated), Effect.asVoid);
    };

    const createChat = (request: Request, userId: string) =>
      http.decodeJson(request, CreateChatCommand).pipe(
        Effect.flatMap(({ dataset }) => {
          const chatId = crypto.randomUUID();
          const chat = env.CHAT_CELL.get(env.CHAT_CELL.idFromName(chatId));
          return Effect.tryPromise(() =>
            chat.fetch('https://chat-cell/initialize', {
              method: 'POST',
              headers: internalHeaders(env, userId),
              body: JSON.stringify({ chatId, dataset }),
            }),
          ).pipe(
            Effect.flatMap((initialized) =>
              Effect.if(initialized.ok, {
                onTrue: () =>
                  Effect.tryPromise(() => initialized.json()).pipe(
                    Effect.flatMap(Schema.decodeUnknown(ChatSummary)),
                    Effect.flatMap((summary) =>
                      storage
                        .transaction((transaction) =>
                          transaction.get<ChatSummaryList>(KEY_CHATS).pipe(
                            Effect.map(storedChats),
                            Effect.flatMap((chats) =>
                              transaction.put(KEY_CHATS, [
                                summary,
                                ...chats.filter((candidate) => candidate.id !== summary.id),
                              ]),
                            ),
                          ),
                        )
                        .pipe(
                          Effect.andThen(
                            platform.broadcast({ type: 'chat-created', data: summary }),
                          ),
                          Effect.as(Response.json(summary, { status: 201, headers: jsonHeaders })),
                        ),
                    ),
                  ),
                onFalse: () => Effect.succeed(initialized),
              }),
            ),
          );
        }),
        Effect.catchTag('HttpError', () =>
          Effect.succeed(Response.json({ error: 'dataset is required' }, { status: 400 })),
        ),
      );

    const updateChatStatus = (request: Request) =>
      http.decodeJson(request, ChatSummary).pipe(
        Effect.flatMap((summary) =>
          storage
            .transaction((transaction) =>
              transaction.get<ChatSummaryList>(KEY_CHATS).pipe(
                Effect.map(storedChats),
                Effect.flatMap((chats) =>
                  transaction.put(
                    KEY_CHATS,
                    [summary, ...chats.filter((chat) => chat.id !== summary.id)].sort(
                      (left, right) => right.updatedAt - left.updatedAt,
                    ),
                  ),
                ),
              ),
            )
            .pipe(
              Effect.andThen(platform.broadcast({ type: 'chat-status', data: summary })),
              Effect.as(new Response(null, { status: 204 })),
            ),
        ),
        Effect.catchTag('HttpError', () =>
          Effect.succeed(Response.json({ error: 'Invalid chat status' }, { status: 400 })),
        ),
      );

    const deleteChat = (chatId: string) =>
      storage
        .transaction((transaction) =>
          transaction.get<ChatSummaryList>(KEY_CHATS).pipe(
            Effect.map(storedChats),
            Effect.flatMap((chats) =>
              transaction.put(
                KEY_CHATS,
                chats.filter((chat) => chat.id !== chatId),
              ),
            ),
          ),
        )
        .pipe(
          Effect.andThen(platform.broadcast({ type: 'chat-deleted', data: { chatId } })),
          Effect.as(new Response(null, { status: 204 })),
        );

    const fetchForUser = (request: Request, userId: string) =>
      ensureHydrated(userId).pipe(
        Effect.andThen(Effect.sync(() => new URL(request.url))),
        Effect.flatMap((url) =>
          Match.value({ method: request.method, path: url.pathname }).pipe(
            Match.when({ method: 'GET', path: '/socket' }, () =>
              storage
                .get<ChatSummaryList>(KEY_CHATS)
                .pipe(Effect.map(storedChats), Effect.flatMap(platform.upgrade)),
            ),
            Match.when({ method: 'POST', path: '/chats' }, () => createChat(request, userId)),
            Match.when({ method: 'PATCH', path: '/chat-status' }, () => updateChatStatus(request)),
            Match.when(
              ({ method, path }) => method === 'DELETE' && path.startsWith('/chats/'),
              ({ path }) => deleteChat(path.slice('/chats/'.length)),
            ),
            Match.orElse(() =>
              Effect.succeed(Response.json({ error: 'Not found' }, { status: 404 })),
            ),
          ),
        ),
      );

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

    return {
      fetch,
      webSocketMessage: platform.webSocketMessage,
      webSocketClose: platform.webSocketClose,
    } as const;
  }),
}) {}

export const makeUserCellRuntime = (
  state: DurableObjectState,
  env: Env,
): ManagedRuntime.ManagedRuntime<UserCellService, never> => {
  const environment = Layer.succeed(Environment, env);
  const app = LiveLayer.pipe(Layer.provide(environment));
  const storage = makeCellStorageLayer(state.storage);
  const platform = makeCellPlatformLayer(state);
  const dependencies = Layer.mergeAll(app, environment, storage, platform);
  return ManagedRuntime.make(UserCellService.Default.pipe(Layer.provide(dependencies)));
};
