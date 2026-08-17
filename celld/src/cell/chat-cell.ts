import { Effect } from 'effect';
import { ChatCellService, makeChatCellRuntime } from '../services/ChatCellService';
import type { Env } from '../types';

export class ChatCell implements DurableObject {
  private readonly runtime;

  constructor(state: DurableObjectState, env: Env) {
    this.runtime = makeChatCellRuntime(state, env);
  }

  fetch(request: Request) {
    return this.runtime.runPromise(
      Effect.gen(function* () {
        const cell = yield* ChatCellService;
        return yield* cell.fetch(request);
      }),
    );
  }

  alarm() {
    return this.runtime.runPromise(
      Effect.gen(function* () {
        const cell = yield* ChatCellService;
        return yield* cell.alarm;
      }),
    );
  }

  webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): void {
    this.runtime.runSync(
      Effect.gen(function* () {
        const cell = yield* ChatCellService;
        return yield* cell.webSocketMessage(socket, message);
      }),
    );
  }

  webSocketClose(socket: WebSocket): void {
    this.runtime.runSync(
      Effect.gen(function* () {
        const cell = yield* ChatCellService;
        return yield* cell.webSocketClose(socket);
      }),
    );
  }
}
