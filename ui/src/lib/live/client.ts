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

const bootstrap = async () => {
  const response = await fetch('/api/live-session', { method: 'POST', credentials: 'same-origin' });
  if (!response.ok) throw new Error('Unable to start live session');
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
  private sequence = 0;

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

  setSequence(sequence: number) {
    this.sequence = Math.max(this.sequence, sequence);
  }

  private async connect() {
    try {
      await bootstrap();
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
  await bootstrap();
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
  await bootstrap();
  const response = await fetch(`/live/chats/${chatId}`, {
    method: 'DELETE',
    credentials: 'same-origin',
  });
  if (!response.ok) throw new Error(await response.text());
};

export const sendMessage = async (chatId: string, content: string) => {
  await bootstrap();
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
