import { Effect } from 'effect';
import { UserCellService, makeUserCellRuntime } from '../services/UserCellService';
import type { Env } from '../types';

export class UserCell implements DurableObject {
  private readonly runtime;

  constructor(state: DurableObjectState, env: Env) {
    this.runtime = makeUserCellRuntime(state, env);
  }

  fetch(request: Request) {
    return this.runtime.runPromise(
      Effect.gen(function* () {
        const cell = yield* UserCellService;
        return yield* cell.fetch(request);
      }),
    );
  }

  webSocketMessage(socket: WebSocket, message: string | ArrayBuffer): void {
    this.runtime.runSync(
      Effect.gen(function* () {
        const cell = yield* UserCellService;
        return yield* cell.webSocketMessage(socket, message);
      }),
    );
  }

  webSocketClose(socket: WebSocket): void {
    this.runtime.runSync(
      Effect.gen(function* () {
        const cell = yield* UserCellService;
        return yield* cell.webSocketClose(socket);
      }),
    );
  }
}
