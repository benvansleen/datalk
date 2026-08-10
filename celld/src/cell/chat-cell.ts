import { Effect } from 'effect';
import { runEffect } from '../runtime';
import { Agent, GenerationSink, type GenerationSinkShape } from '../services/Agent';
import { InternalApi } from '../services/InternalApi';
import { Projection } from '../services/Projection';
import type { Env, GenerationEvent } from '../types';
import { InitializeCommand, SubmitMessageCommand } from '../types';
import {
  KEY_CHAT_ID,
  KEY_SNAPSHOT,
  broadcast,
  decodeRequestJson,
  emptySnapshot,
  internalHeaders,
  isInternalRequest,
  jsonHeaders,
  pong,
  summaryOf,
  upgradeSocket,
  type StoredChatSnapshot,
} from './shared';

const MAX_EVENTS = 1_000;

export class ChatCell implements DurableObject {
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
    const url = new URL(request.url);

    if (request.method === 'POST' && url.pathname === '/initialize') {
      return this.initialize(request, userId);
    }

    const requestedChatId = request.headers.get('x-datalk-chat-id');
    if (requestedChatId) await this.state.storage.put(KEY_CHAT_ID, requestedChatId);
    const snapshot =
      (await this.state.storage.get<StoredChatSnapshot>(KEY_SNAPSHOT)) ??
      (await this.hydrate(userId));
    if (!snapshot) return Response.json({ error: 'Chat is not initialized' }, { status: 404 });
    if (snapshot.userId !== userId) return Response.json({ error: 'Forbidden' }, { status: 403 });
    if (snapshot.deleted) return Response.json({ error: 'Chat was deleted' }, { status: 404 });

    if (request.method === 'DELETE' && url.pathname === '/') return this.deleteChat(snapshot);
    if (request.method === 'GET' && url.pathname === '/snapshot') {
      return Response.json(snapshot, { headers: jsonHeaders });
    }
    if (request.method === 'GET' && url.pathname === '/socket') return this.upgradeSocket(snapshot);
    if (request.method === 'POST' && url.pathname === '/messages') {
      return this.submitMessage(request, snapshot);
    }
    return Response.json({ error: 'Not found' }, { status: 404 });
  }

  async alarm(): Promise<void> {
    const state = this.state;
    await runEffect(
      this.env,
      Effect.gen(function* () {
        const projection = yield* Projection;
        return yield* projection.flushProjection(state);
      }),
    );
  }

  private async initialize(request: Request, userId: string): Promise<Response> {
    const body = await decodeRequestJson(InitializeCommand, request);
    if (!body) {
      return Response.json({ error: 'chatId and dataset are required' }, { status: 400 });
    }
    const { chatId, dataset } = body;
    const snapshot =
      (await this.state.storage.get<StoredChatSnapshot>(KEY_SNAPSHOT)) ??
      emptySnapshot(chatId, userId, dataset);
    if (snapshot.userId !== userId) return Response.json({ error: 'Forbidden' }, { status: 403 });
    await this.state.storage.put(KEY_CHAT_ID, chatId);
    await this.save(snapshot);
    return Response.json(summaryOf(snapshot), { headers: jsonHeaders });
  }

  private async deleteChat(snapshot: StoredChatSnapshot): Promise<Response> {
    snapshot.deleted = true;
    snapshot.generating = false;
    this.appendEvent(snapshot, 'chat-deleted', { chatId: snapshot.id });
    await this.save(snapshot);
    return new Response(null, { status: 204 });
  }

  private async submitMessage(request: Request, snapshot: StoredChatSnapshot): Promise<Response> {
    const body = await decodeRequestJson(SubmitMessageCommand, request);
    if (!body) {
      return Response.json(
        { error: 'content must be between 1 and 32000 characters' },
        { status: 400 },
      );
    }
    const { content } = body;
    if (snapshot.generating) {
      return Response.json({ error: 'Already generating a response' }, { status: 409 });
    }

    const requestId = crypto.randomUUID();
    snapshot.generating = true;
    snapshot.currentMessageRequestId = requestId;
    snapshot.messages.push({ id: requestId, role: 'user', content, createdAt: Date.now() });
    this.appendEvent(snapshot, 'message-submitted', { messageRequestId: requestId, content });
    this.appendEvent(snapshot, 'generation-started', { messageRequestId: requestId });
    await this.save(snapshot);
    this.state.waitUntil(this.generate(requestId));
    return Response.json({ messageRequestId: requestId }, { status: 202, headers: jsonHeaders });
  }

  private async generate(messageRequestId: string): Promise<void> {
    const snapshot = await this.state.storage.get<StoredChatSnapshot>(KEY_SNAPSHOT);
    if (!snapshot || !snapshot.generating || snapshot.deleted) return;
    const sink: GenerationSinkShape = {
      append: (type, data) => Effect.sync(() => this.appendEvent(snapshot, type, data)),
      emit: (type, data) =>
        Effect.sync(() => {
          const event = this.appendEvent(snapshot, type, data);
          this.broadcast({ type: 'event', data: event });
        }),
      save: () => Effect.promise(() => this.save(snapshot)),
      spawn: (work) =>
        Effect.sync(() => {
          this.state.waitUntil(runEffect(this.env, work));
        }),
    };
    try {
      await runEffect(
        this.env,
        Effect.gen(function* () {
          const agent = yield* Agent;
          return yield* agent.runGeneration(snapshot, messageRequestId);
        }).pipe(Effect.provideService(GenerationSink, sink)),
      );
    } finally {
      snapshot.generating = false;
      snapshot.currentMessageRequestId = null;
      await this.save(snapshot);
    }
  }

  private async hydrate(userId: string): Promise<StoredChatSnapshot | null> {
    const chatId = await this.state.storage.get<string>(KEY_CHAT_ID);
    if (!chatId) return null;
    const hydrated = await runEffect(
      this.env,
      Effect.gen(function* () {
        const api = yield* InternalApi;
        return yield* api.hydrateChat(chatId, userId);
      }),
    );
    if (!hydrated) return null;
    const snapshot = hydrated as StoredChatSnapshot;
    await this.state.storage.put(KEY_SNAPSHOT, snapshot);
    return snapshot;
  }

  private appendEvent(snapshot: StoredChatSnapshot, type: string, data: unknown): GenerationEvent {
    const event = {
      sequence: (snapshot.events.at(-1)?.sequence ?? 0) + 1,
      type,
      data,
      createdAt: Date.now(),
    };
    snapshot.events = [...snapshot.events, event].slice(-MAX_EVENTS);
    return event;
  }

  private async save(snapshot: StoredChatSnapshot): Promise<void> {
    snapshot.updatedAt = Date.now();
    await this.state.storage.put(KEY_SNAPSHOT, snapshot);
    const state = this.state;
    await runEffect(
      this.env,
      Effect.gen(function* () {
        const projection = yield* Projection;
        return yield* projection.enqueueProjection(state, snapshot);
      }),
    );
    this.state.waitUntil(
      this.notifyUser(snapshot).catch((error) => {
        console.error('User cell notification failed', error);
      }),
    );
    this.broadcast({ type: 'snapshot', data: snapshot });
  }

  private async notifyUser(snapshot: StoredChatSnapshot): Promise<void> {
    const user = this.env.USER_CELL.get(this.env.USER_CELL.idFromName(snapshot.userId));
    await user.fetch('https://user-cell/chat-status', {
      method: 'PATCH',
      headers: internalHeaders(this.env, snapshot.userId),
      body: JSON.stringify(summaryOf(snapshot)),
    });
  }

  private upgradeSocket(snapshot: StoredChatSnapshot): Response {
    return upgradeSocket(this.state, () => snapshot);
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
