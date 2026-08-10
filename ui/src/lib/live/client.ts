export type LiveChatSummary = {
  id: string;
  dataset: string;
  title: string;
  updatedAt: number;
  generating: boolean;
};

export type LiveMessage = {
  id: string;
  role: 'user' | 'assistant' | 'tool';
  content: string;
  createdAt: number;
  toolName?: string;
  toolArguments?: unknown;
  toolResult?: unknown;
};

export type LiveSnapshot = {
  id: string;
  generating: boolean;
  messages: LiveMessage[];
  events: Array<{ sequence: number }>;
};

export type SsrChat = {
  id: string;
  dataset: string;
  title: string | null;
  currentMessageRequest: string | null;
  updatedAt: Date;
};

export type SsrDisplayMessage = {
  role: 'user' | 'assistant' | 'tool';
  content?: string;
  name?: string;
  arguments?: string;
  output?: unknown;
};

export const toLiveChats = (chats: SsrChat[]): LiveChatSummary[] =>
  chats.map((chat) => ({
    id: chat.id,
    dataset: chat.dataset,
    title: chat.title ?? '...',
    generating: chat.currentMessageRequest !== null,
    updatedAt: chat.updatedAt.getTime(),
  }));

export const toLiveMessages = (messages: SsrDisplayMessage[]): LiveMessage[] =>
  messages.map((message, index) => ({
    id: String(index),
    role: message.role,
    content: message.content ?? '',
    createdAt: 0,
    toolName: message.name,
    toolArguments: message.arguments,
    toolResult: message.output,
  }));

export const deletedChatId = (message: unknown): string | undefined => {
  if (!message || typeof message !== 'object' || !('type' in message) || !('data' in message)) {
    return undefined;
  }
  const { type, data } = message as { type: string; data: unknown };
  return type === 'chat-deleted' && !Array.isArray(data)
    ? (data as { chatId?: string }).chatId
    : undefined;
};

export const reduceChats = (chats: LiveChatSummary[], message: unknown): LiveChatSummary[] => {
  if (!message || typeof message !== 'object' || !('type' in message) || !('data' in message)) {
    return chats;
  }
  const { type, data } = message as { type: string; data: unknown };
  if (type === 'snapshot') {
    return Array.isArray(data) ? (data as LiveChatSummary[]) : chats;
  }
  if (type === 'chat-deleted') {
    const chatId = (data as { chatId?: string } | null)?.chatId;
    return chatId ? chats.filter((chat) => chat.id !== chatId) : chats;
  }
  if ((type === 'chat-created' || type === 'chat-status') && !Array.isArray(data)) {
    const summary = data as LiveChatSummary;
    return [summary, ...chats.filter((chat) => chat.id !== summary.id)];
  }
  return chats;
};

type GenerationEvent = { sequence: number; type: string; data: unknown };

export const reduceSnapshot = (snapshot: LiveSnapshot, message: unknown): LiveSnapshot => {
  if (!message || typeof message !== 'object' || !('type' in message) || !('data' in message)) {
    return snapshot;
  }
  const wire = message as { type: string; data: unknown };
  if (wire.type === 'snapshot') {
    return wire.data as LiveSnapshot;
  }
  if (wire.type !== 'event') return snapshot;
  const event = wire.data as GenerationEvent;
  if (event.type === 'text-delta') {
    const { id, delta } = event.data as { id: string; delta: string };
    const index = snapshot.messages.findIndex((message) => message.id === id);
    return {
      ...snapshot,
      messages:
        index === -1
          ? [...snapshot.messages, { id, role: 'assistant', content: delta, createdAt: Date.now() }]
          : snapshot.messages.map((message, messageIndex) =>
              messageIndex === index ? { ...message, content: message.content + delta } : message,
            ),
    };
  }
  if (event.type === 'tool-params-start') {
    const { id, name } = event.data as { id: string; name: string };
    if (snapshot.messages.some((message) => message.id === id)) return snapshot;
    return {
      ...snapshot,
      messages: [
        ...snapshot.messages,
        {
          id,
          role: 'tool',
          content: '',
          createdAt: Date.now(),
          toolName: name,
          toolArguments: '',
        },
      ],
    };
  }
  if (event.type === 'tool-params-delta') {
    const { id, delta } = event.data as { id: string; delta: string };
    return {
      ...snapshot,
      messages: snapshot.messages.map((message) =>
        message.id === id
          ? {
              ...message,
              toolArguments: `${
                typeof message.toolArguments === 'string' ? message.toolArguments : ''
              }${delta}`,
            }
          : message,
      ),
    };
  }
  if (event.type === 'tool-call') {
    const { id, name, params } = event.data as { id: string; name: string; params: string };
    const existing = snapshot.messages.some((message) => message.id === id);
    return {
      ...snapshot,
      messages: existing
        ? snapshot.messages.map((message) =>
            message.id === id ? { ...message, toolName: name, toolArguments: params } : message,
          )
        : [
            ...snapshot.messages,
            {
              id,
              role: 'tool',
              content: '',
              createdAt: Date.now(),
              toolName: name,
              toolArguments: params,
            },
          ],
    };
  }
  if (event.type === 'tool-result') {
    const { id, result } = event.data as { id: string; result: unknown };
    return {
      ...snapshot,
      messages: snapshot.messages.map((message) =>
        message.id === id ? { ...message, toolResult: result } : message,
      ),
    };
  }
  return snapshot;
};

const socketUrl = (path: string) => {
  const url = new URL(path, location.origin);
  url.protocol = url.protocol === 'https:' ? 'wss:' : 'ws:';
  return url;
};

export class LiveClient {
  private socket: WebSocket | null = null;
  private retryTimer: ReturnType<typeof setTimeout> | null = null;
  private stopped = false;
  private attempts = 0;

  constructor(
    private readonly path: () => string,
    private readonly receive: (message: unknown) => void,
  ) {}

  start() {
    void this.connect();
  }

  stop() {
    this.stopped = true;
    this.socket?.close();
    if (this.retryTimer) clearTimeout(this.retryTimer);
  }

  private async connect() {
    try {
      if (this.stopped) return;
      const socket = new WebSocket(socketUrl(this.path()));
      this.socket = socket;
      socket.onopen = () => (this.attempts = 0);
      socket.onmessage = (event) => {
        try {
          this.receive(JSON.parse(String(event.data)));
        } catch {
          socket.close();
        }
      };
      socket.onclose = () => this.scheduleReconnect();
      socket.onerror = () => socket.close();
    } catch {
      this.scheduleReconnect();
    }
  }

  private scheduleReconnect() {
    if (this.stopped || this.retryTimer) return;
    const delay = Math.min(10_000, 500 * 2 ** this.attempts++);
    this.retryTimer = setTimeout(() => {
      this.retryTimer = null;
      void this.connect();
    }, delay);
  }
}

export const createChat = async (dataset: string): Promise<LiveChatSummary> => {
  const response = await fetch('/live/chats', {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ dataset }),
  });
  if (!response.ok) throw new Error(await response.text());
  return response.json();
};

export const deleteChat = async (chatId: string) => {
  const response = await fetch(`/live/chats/${chatId}`, {
    method: 'DELETE',
    credentials: 'same-origin',
  });
  if (!response.ok) throw new Error(await response.text());
};

export const sendMessage = async (chatId: string, content: string) => {
  const response = await fetch(`/live/chats/${chatId}/messages`, {
    method: 'POST',
    credentials: 'same-origin',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ content }),
  });
  if (response.status === 409) throw new Error('A response is already generating');
  if (!response.ok) throw new Error(await response.text());
  return response.json() as Promise<{ messageRequestId: string }>;
};
