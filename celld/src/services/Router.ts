import { HttpRouter, HttpServerRequest, HttpServerResponse } from '@effect/platform';
import { Context, Effect, Option, Schema } from 'effect';
import { CreateChatCommand, HttpError, SubmitMessageCommand, type Env } from '../types';
import { Http, HttpLive } from './Http';
import { Observability, ObservabilityLive } from './Observability';

type RouteContext = {
  request: Request;
  url: URL;
  env: Env;
  userId: string;
};

type Handler = (ctx: RouteContext) => Effect.Effect<Response, HttpError>;

class LiveRequest extends Context.Tag('app/Router/LiveRequest')<LiveRequest, RouteContext>() {}

const ChatPathParams = Schema.Struct({ chatId: Schema.String });
const ChatImagePathParams = Schema.Struct({ chatId: Schema.String, imageId: Schema.String });

export class Router extends Effect.Service<Router>()('app/Router', {
  effect: Effect.gen(function* () {
    const http = yield* Http;
    const observability = yield* Observability;

    const internalHeaders = (env: Env, userId: string, chatId?: string): HeadersInit => ({
      'content-type': 'application/json',
      'x-datalk-internal-secret': env.INTERNAL_CELL_SECRET,
      'x-datalk-user-id': userId,
      ...(chatId ? { 'x-datalk-chat-id': chatId } : {}),
    });

    const cellRequest = (
      stub: DurableObjectStub,
      path: string,
      userId: string,
      env: Env,
      init: RequestInit = {},
      chatId?: string,
    ): Effect.Effect<Response, HttpError> =>
      Effect.tryPromise({
        try: () =>
          stub.fetch(`https://cell${path}`, {
            ...init,
            headers: {
              ...internalHeaders(env, userId, chatId),
              ...init.headers,
            },
          }),
        catch: () => new HttpError({ status: 503, message: 'Live cell is unavailable' }),
      });

    const requireUpgrade = (request: Request): Effect.Effect<void, HttpError> =>
      Effect.if(request.headers.get('upgrade')?.toLowerCase() === 'websocket', {
        onTrue: () => Effect.void,
        onFalse: () =>
          Effect.fail(new HttpError({ status: 426, message: 'WebSocket upgrade required' })),
      });

    const userCell = (ctx: RouteContext) =>
      ctx.env.USER_CELL.get(ctx.env.USER_CELL.idFromName(ctx.userId));

    const chatCell = (ctx: RouteContext, chatId: string) =>
      ctx.env.CHAT_CELL.get(ctx.env.CHAT_CELL.idFromName(chatId));

    const openUserSocket: Handler = (ctx) =>
      requireUpgrade(ctx.request).pipe(
        Effect.flatMap(() =>
          cellRequest(userCell(ctx), '/socket', ctx.userId, ctx.env, {
            headers: { upgrade: 'websocket' },
          }),
        ),
      );

    const createChat: Handler = (ctx) =>
      http.decodeJson(ctx.request, CreateChatCommand).pipe(
        Effect.flatMap((body) =>
          cellRequest(userCell(ctx), '/chats', ctx.userId, ctx.env, {
            method: 'POST',
            body: JSON.stringify(body),
          }),
        ),
      );

    const deleteChat = (ctx: RouteContext, chatId: string) => {
      return cellRequest(
        chatCell(ctx, chatId),
        '/',
        ctx.userId,
        ctx.env,
        { method: 'DELETE' },
        chatId,
      ).pipe(
        Effect.flatMap((response) =>
          Effect.if(response.ok, {
            onTrue: () =>
              cellRequest(userCell(ctx), `/chats/${chatId}`, ctx.userId, ctx.env, {
                method: 'DELETE',
              }),
            onFalse: () => Effect.succeed(response),
          }),
        ),
      );
    };

    const submitMessage = (ctx: RouteContext, chatId: string) => {
      return http.decodeJson(ctx.request, SubmitMessageCommand).pipe(
        Effect.flatMap((body) =>
          cellRequest(
            chatCell(ctx, chatId),
            '/messages',
            ctx.userId,
            ctx.env,
            {
              method: 'POST',
              body: JSON.stringify(body),
            },
            chatId,
          ),
        ),
      );
    };

    const openChatSocket = (ctx: RouteContext, chatId: string) => {
      return requireUpgrade(ctx.request).pipe(
        Effect.flatMap(() =>
          cellRequest(
            chatCell(ctx, chatId),
            `/socket${ctx.url.search}`,
            ctx.userId,
            ctx.env,
            { headers: { upgrade: 'websocket' } },
            chatId,
          ),
        ),
      );
    };

    const chatId = HttpRouter.schemaPathParams(ChatPathParams).pipe(
      Effect.map(({ chatId }) => chatId),
      Effect.mapError(() => new HttpError({ status: 400, message: 'Invalid chat id' })),
    );

    const chatImagePath = HttpRouter.schemaPathParams(ChatImagePathParams).pipe(
      Effect.mapError(() => new HttpError({ status: 400, message: 'Invalid image id' })),
    );

    const getChatImage = (ctx: RouteContext, chatId: string, imageId: string) =>
      cellRequest(chatCell(ctx, chatId), `/images/${imageId}`, ctx.userId, ctx.env, {}, chatId);

    const withChatImage = (
      handler: (
        ctx: RouteContext,
        chatId: string,
        imageId: string,
      ) => Effect.Effect<Response, HttpError>,
    ) =>
      Effect.all([LiveRequest, chatImagePath]).pipe(
        Effect.flatMap(([ctx, { chatId, imageId }]) => handler(ctx, chatId, imageId)),
      );

    const withRequest = (handler: Handler) => LiveRequest.pipe(Effect.flatMap(handler));

    const withChatId = (
      handler: (ctx: RouteContext, chatId: string) => Effect.Effect<Response, HttpError>,
    ) =>
      Effect.all([LiveRequest, chatId]).pipe(
        Effect.flatMap(([ctx, chatId]) => handler(ctx, chatId)),
      );

    // HttpServerResponse.fromWeb cannot retain Cloudflare's WebSocket attachment. Keep the
    // original response associated with its platform wrapper so upgrades cross unchanged.
    const nativeResponses = new WeakMap<HttpServerResponse.HttpServerResponse, Response>();
    const wrapResponse = (response: Response): HttpServerResponse.HttpServerResponse => {
      const wrapped = HttpServerResponse.fromWeb(response);
      nativeResponses.set(wrapped, response);
      return wrapped;
    };
    const unwrapResponse = (response: HttpServerResponse.HttpServerResponse): Response =>
      Option.fromNullable(nativeResponses.get(response)).pipe(
        Option.getOrElse(() => HttpServerResponse.toWeb(response)),
      );

    const tracked = <R>(
      name: string,
      method: string,
      handler: Effect.Effect<Response, HttpError, R>,
    ): Effect.Effect<HttpServerResponse.HttpServerResponse, HttpError, R> => {
      let status = Option.none<number>();
      return observability
        .track(
          'app.live.command',
          handler.pipe(
            Effect.tap((response) =>
              Effect.sync(() => {
                status = Option.some(response.status);
              }),
            ),
          ),
          () => ({
            'app.command.name': name,
            'http.request.method': method,
            ...Option.match(status, {
              onNone: () => ({}),
              onSome: (responseStatus) => ({
                'http.response.status_code': responseStatus,
              }),
            }),
          }),
        )
        .pipe(Effect.map(wrapResponse));
    };

    const app = HttpRouter.empty.pipe(
      HttpRouter.get(
        '/live/socket',
        tracked('open_user_socket', 'GET', withRequest(openUserSocket)),
      ),
      HttpRouter.post('/live/chats', tracked('create_chat', 'POST', withRequest(createChat))),
      HttpRouter.del(
        '/live/chats/:chatId',
        tracked('delete_chat', 'DELETE', withChatId(deleteChat)),
      ),
      HttpRouter.post(
        '/live/chats/:chatId/messages',
        tracked('submit_message', 'POST', withChatId(submitMessage)),
      ),
      HttpRouter.get(
        '/live/chats/:chatId/socket',
        tracked('open_chat_socket', 'GET', withChatId(openChatSocket)),
      ),
      HttpRouter.get(
        '/live/chats/:chatId/images/:imageId',
        tracked('get_chat_image', 'GET', withChatImage(getChatImage)),
      ),
    );

    const route = (
      request: Request,
      url: URL,
      env: Env,
      userId: string,
    ): Effect.Effect<Response, HttpError> =>
      app.pipe(
        Effect.provideService(LiveRequest, { request, url, env, userId }),
        Effect.provideService(
          HttpServerRequest.HttpServerRequest,
          HttpServerRequest.fromWeb(request),
        ),
        Effect.scoped,
        Effect.catchTag('RouteNotFound', () =>
          Effect.fail(new HttpError({ status: 404, message: 'Not found' })),
        ),
        Effect.map(unwrapResponse),
      );

    return {
      route,
    } as const;
  }),

  dependencies: [HttpLive, ObservabilityLive],
}) {}

export const RouterLive = Router.Default;
