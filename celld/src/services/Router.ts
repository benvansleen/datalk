import { Effect } from 'effect';
import { CreateChatCommand, HttpError, SubmitMessageCommand, type Env } from '../types';
import { Http, HttpLive } from './Http';
import { Observability, ObservabilityLive } from './Observability';

type RouteContext = {
  request: Request;
  url: URL;
  env: Env;
  userId: string;
  params: Record<string, string>;
};

type Handler = (ctx: RouteContext) => Effect.Effect<Response, HttpError>;

type Route = { name: string; method: string; pattern: RegExp; handle: Handler };

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
      request.headers.get('upgrade')?.toLowerCase() === 'websocket'
        ? Effect.succeed(undefined)
        : Effect.fail(new HttpError({ status: 426, message: 'WebSocket upgrade required' }));

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

    const deleteChat: Handler = (ctx) => {
      const chatId = ctx.params.chatId;
      return cellRequest(
        chatCell(ctx, chatId),
        '/',
        ctx.userId,
        ctx.env,
        { method: 'DELETE' },
        chatId,
      ).pipe(
        Effect.flatMap((response) =>
          response.ok
            ? cellRequest(userCell(ctx), `/chats/${chatId}`, ctx.userId, ctx.env, {
                method: 'DELETE',
              })
            : Effect.succeed(response),
        ),
      );
    };

    const submitMessage: Handler = (ctx) => {
      const chatId = ctx.params.chatId;
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

    const openChatSocket: Handler = (ctx) => {
      const chatId = ctx.params.chatId;
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

    const routes: ReadonlyArray<Route> = [
      {
        name: 'open_user_socket',
        method: 'GET',
        pattern: /^\/live\/socket$/,
        handle: openUserSocket,
      },
      { name: 'create_chat', method: 'POST', pattern: /^\/live\/chats$/, handle: createChat },
      {
        name: 'delete_chat',
        method: 'DELETE',
        pattern: /^\/live\/chats\/(?<chatId>[^/]+)$/,
        handle: deleteChat,
      },
      {
        name: 'submit_message',
        method: 'POST',
        pattern: /^\/live\/chats\/(?<chatId>[^/]+)\/messages$/,
        handle: submitMessage,
      },
      {
        name: 'open_chat_socket',
        method: 'GET',
        pattern: /^\/live\/chats\/(?<chatId>[^/]+)\/socket$/,
        handle: openChatSocket,
      },
    ];

    const route = (
      request: Request,
      url: URL,
      env: Env,
      userId: string,
    ): Effect.Effect<Response, HttpError> => {
      for (const { name, method, pattern, handle } of routes) {
        if (request.method !== method) continue;
        const match = pattern.exec(url.pathname);
        if (!match) continue;
        let status: number | undefined;
        return observability.track(
          'app.live.command',
          handle({ request, url, env, userId, params: match.groups ?? {} }).pipe(
            Effect.tap((response) =>
              Effect.sync(() => {
                status = response.status;
              }),
            ),
          ),
          () => ({
            'app.command.name': name,
            'http.request.method': method,
            'http.response.status_code': status,
          }),
        );
      }
      return Effect.fail(new HttpError({ status: 404, message: 'Not found' }));
    };

    return {
      route,
    } as const;
  }),

  dependencies: [HttpLive, ObservabilityLive],
}) {}

export const RouterLive = Router.Default;
