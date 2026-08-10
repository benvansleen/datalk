import { Effect, Exit } from 'effect';
import { runEffectExit } from '../runtime';
import { InternalApi } from '../services/InternalApi';
import type { ChatSummary, Env } from '../types';
import { CreateChatCommand } from '../types';
import {
  broadcast,
  decodeRequestJson,
  internalHeaders,
  isInternalRequest,
  jsonHeaders,
  pong,
  upgradeSocket,
} from './shared';

const KEY_CHATS = 'chats';
const KEY_HYDRATED = 'hydrated';

export class UserCell implements DurableObject {
  constructor(
    private readonly state: DurableObjectState,
    private readonly env: Env,
  ) {}

  async fetch(request: Request): Promise<Response> {
    if (!isInternalRequest(request, this.env)) {
      return Response.json({ error: 'Forbidden' }, { status: 403 });
    }
    const userId = request.headers.get('x-datalk-user-id');
    if (!userId) return Response.json({ error: 'Missing user identity' }, { status: 400 });
    await this.ensureHydrated(userId);

    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/socket') return this.upgradeSocket();
    if (request.method === 'POST' && url.pathname === '/chats') {
      return this.createChat(request, userId);
    }
    if (request.method === 'PATCH' && url.pathname === '/chat-status') {
      return this.updateChatStatus(request);
    }
    if (request.method === 'DELETE' && url.pathname.startsWith('/chats/')) {
      return this.deleteChat(url.pathname.slice('/chats/'.length));
    }
    return Response.json({ error: 'Not found' }, { status: 404 });
  }

  private async createChat(request: Request, userId: string): Promise<Response> {
    const body = await decodeRequestJson(CreateChatCommand, request);
    if (!body) {
      return Response.json({ error: 'dataset is required' }, { status: 400 });
    }
    const { dataset } = body;
    const chatId = crypto.randomUUID();
    const chat = this.env.CHAT_CELL.get(this.env.CHAT_CELL.idFromName(chatId));
    const initialized = await chat.fetch('https://chat-cell/initialize', {
      method: 'POST',
      headers: internalHeaders(this.env, userId),
      body: JSON.stringify({ chatId, dataset }),
    });
    if (!initialized.ok) return initialized;
    const summary = (await initialized.json()) as ChatSummary;
    const chats = (await this.state.storage.get<ChatSummary[]>(KEY_CHATS)) ?? [];
    await this.state.storage.put(KEY_CHATS, [
      summary,
      ...chats.filter((chat) => chat.id !== summary.id),
    ]);
    this.broadcast({ type: 'chat-created', data: summary });
    return Response.json(summary, { status: 201, headers: jsonHeaders });
  }

  private async updateChatStatus(request: Request): Promise<Response> {
    const summary = (await request.json()) as ChatSummary;
    const chats = (await this.state.storage.get<ChatSummary[]>(KEY_CHATS)) ?? [];
    await this.state.storage.put(
      KEY_CHATS,
      [summary, ...chats.filter((chat) => chat.id !== summary.id)].sort(
        (left, right) => right.updatedAt - left.updatedAt,
      ),
    );
    this.broadcast({ type: 'chat-status', data: summary });
    return new Response(null, { status: 204 });
  }

  private async deleteChat(chatId: string): Promise<Response> {
    const chats = (await this.state.storage.get<ChatSummary[]>(KEY_CHATS)) ?? [];
    await this.state.storage.put(
      KEY_CHATS,
      chats.filter((chat) => chat.id !== chatId),
    );
    this.broadcast({ type: 'chat-deleted', data: { chatId } });
    return new Response(null, { status: 204 });
  }

  private async ensureHydrated(userId: string): Promise<void> {
    if (await this.state.storage.get<boolean>(KEY_HYDRATED)) return;
    const hydrated = await runEffectExit(
      this.env,
      Effect.gen(function* () {
        const api = yield* InternalApi;
        return yield* api.hydrateUser(userId);
      }),
    );
    if (Exit.isSuccess(hydrated)) {
      await this.state.storage.put(KEY_CHATS, hydrated.value as ChatSummary[]);
      await this.state.storage.put(KEY_HYDRATED, true);
    }
  }

  private upgradeSocket(): Response {
    return upgradeSocket(
      this.state,
      async () => (await this.state.storage.get<ChatSummary[]>(KEY_CHATS)) ?? [],
    );
  }

  private broadcast(value: unknown): void {
    broadcast(this.state, value);
  }

  webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): void {
    pong(socket, message);
  }

  webSocketClose(socket: WebSocket): void {
    socket.close();
  }
}
