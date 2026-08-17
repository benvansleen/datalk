import { Effect, Schema } from 'effect';
import { Config, ConfigLive } from './Config';
import { HttpError } from '../types';

const EnvironmentResponse = Schema.Struct({ available_dataframes: Schema.String });

export const ImageAttachment = Schema.Struct({
  id: Schema.String,
  mime: Schema.String,
  data: Schema.String,
});

const ExecuteResponse = Schema.Struct({
  outputs: Schema.String,
  images: Schema.optional(Schema.Array(ImageAttachment)),
});

export type ExecuteResult = {
  outputs: string;
  images: ReadonlyArray<{ id: string; mime: string; data: string }>;
};

export class PythonServer extends Effect.Service<PythonServer>()('app/PythonServer', {
  effect: Effect.gen(function* () {
    const config = yield* Config;

    const request = <A, I>(path: string, init: RequestInit, schema: Schema.Schema<A, I>) =>
      Effect.tryPromise({
        try: () => fetch(new URL(path, config.pythonServerUrl), init),
        catch: () => new HttpError({ status: 502, message: 'Execution service is unavailable' }),
      }).pipe(
        Effect.flatMap((response) =>
          response.ok
            ? Effect.tryPromise({
                try: () => response.json(),
                catch: () =>
                  new HttpError({
                    status: 502,
                    message: 'Execution service returned invalid JSON',
                  }),
              })
            : Effect.fail(
                new HttpError({
                  status: 502,
                  message: `Execution service failed (${response.status})`,
                }),
              ),
        ),
        Effect.flatMap(Schema.decodeUnknown(schema)),
        Effect.mapError((error) =>
          error instanceof HttpError
            ? error
            : new HttpError({
                status: 502,
                message: `Invalid execution service response: ${String(error)}`,
              }),
        ),
      );

    const createEnvironment = (chatId: string, dataset: string) =>
      request(
        '/environment/create',
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId, dataset }),
        },
        EnvironmentResponse,
      );

    const execute = (
      chatId: string,
      code: string[],
      language: 'python' | 'sql',
    ): Effect.Effect<ExecuteResult, HttpError> =>
      request(
        '/execute',
        {
          method: 'POST',
          headers: { 'content-type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId, code, language }),
        },
        ExecuteResponse,
      ).pipe(Effect.map(({ outputs, images }) => ({ outputs, images: images ?? [] })));

    return { createEnvironment, execute } as const;
  }),
  dependencies: [ConfigLive],
}) {}

export const PythonServerLive = PythonServer.Default;
