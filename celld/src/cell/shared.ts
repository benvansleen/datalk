import { Schema } from 'effect';
import type { ChatMessage, ChatSummary, Env, GenerationEvent } from '../types';

export const jsonHeaders = {
  'content-type': 'application/json',
  'cache-control': 'no-store',
};

export const KEY_SNAPSHOT = 'snapshot';
export const KEY_CHAT_ID = 'chat-id';

export type StoredChatSnapshot = {
  id: string;
  userId: string;
  dataset: string;
  title: string;
  deleted: boolean;
  generating: boolean;
  currentMessageRequestId: string | null;
  createdAt: number;
  updatedAt: number;
  messages: ChatMessage[];
  events: GenerationEvent[];
};

export const emptySnapshot = (id: string, userId: string, dataset: string): StoredChatSnapshot => ({
  id,
  userId,
  dataset,
  title: '...',
  deleted: false,
  generating: false,
  currentMessageRequestId: null,
  createdAt: Date.now(),
  updatedAt: Date.now(),
  messages: [],
  events: [],
});

export const summaryOf = (snapshot: StoredChatSnapshot): ChatSummary => ({
  id: snapshot.id,
  dataset: snapshot.dataset,
  title: snapshot.title,
  updatedAt: snapshot.events.at(-1)?.createdAt ?? 0,
  generating: snapshot.generating,
});

export const isInternalRequest = (request: Request, env: Env) =>
  request.headers.get('x-datalk-internal-secret') === env.INTERNAL_CELL_SECRET;

export const internalHeaders = (env: Env, userId: string, chatId?: string): HeadersInit => ({
  ...jsonHeaders,
  'x-datalk-internal-secret': env.INTERNAL_CELL_SECRET,
  'x-datalk-user-id': userId,
  ...(chatId ? { 'x-datalk-chat-id': chatId } : {}),
});

export const decodeRequestJson = <A>(
  schema: Schema.Schema<A>,
  request: Request,
): Promise<A | null> =>
  request
    .json()
    .then((body) => {
      try {
        return Schema.decodeUnknownSync(schema)(body);
      } catch {
        return null;
      }
    })
    .catch(() => null);

export const upgradeSocket = (
  state: DurableObjectState,
  snapshot: () => unknown | Promise<unknown>,
): Response => {
  const pair = new WebSocketPair();
  const server = pair[0];
  const client = pair[1];
  state.acceptWebSocket(server);
  void Promise.resolve(snapshot()).then((data) =>
    server.send(JSON.stringify({ type: 'snapshot', data })),
  );
  return new Response(null, { status: 101, webSocket: client });
};

export const broadcast = (state: DurableObjectState, value: unknown): void => {
  const message = JSON.stringify(value);
  for (const socket of state.getWebSockets()) socket.send(message);
};

export const pong = (socket: WebSocket, message: string | ArrayBuffer): void => {
  if (typeof message === 'string' && message === 'ping') socket.send('pong');
};
