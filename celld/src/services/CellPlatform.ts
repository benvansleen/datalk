import { Context, Effect, Layer } from 'effect';

type CellPlatformBackendShape = {
  state: DurableObjectState;
};

class CellPlatformBackend extends Context.Tag('app/CellPlatformBackend')<
  CellPlatformBackend,
  CellPlatformBackendShape
>() {}

export class CellPlatform extends Effect.Service<CellPlatform>()('app/CellPlatform', {
  effect: Effect.gen(function* () {
    const { state } = yield* CellPlatformBackend;

    const fork = <A, E>(work: Effect.Effect<A, E>) =>
      Effect.sync(() => {
        state.waitUntil(Effect.runPromise(work));
      });

    const upgrade = (snapshot: unknown) =>
      Effect.sync(() => {
        const pair = new WebSocketPair();
        const server = pair[0];
        const client = pair[1];
        state.acceptWebSocket(server);
        server.send(JSON.stringify({ type: 'snapshot', data: snapshot }));
        return new Response(null, { status: 101, webSocket: client });
      });

    const broadcast = (value: unknown) =>
      Effect.sync(() => {
        const message = JSON.stringify(value);
        for (const socket of state.getWebSockets()) socket.send(message);
      });

    const webSocketMessage = (socket: WebSocket, message: string | ArrayBuffer) =>
      Effect.sync(() => {
        if (typeof message === 'string' && message === 'ping') socket.send('pong');
      });

    const webSocketClose = (socket: WebSocket) => Effect.sync(() => socket.close());

    return { fork, upgrade, broadcast, webSocketMessage, webSocketClose } as const;
  }),
}) {}

export const makeCellPlatformLayer = (state: DurableObjectState): Layer.Layer<CellPlatform> =>
  CellPlatform.Default.pipe(Layer.provide(Layer.succeed(CellPlatformBackend, { state })));
