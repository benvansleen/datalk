import { Effect, Schema } from 'effect';
import { Config } from './Config';
import { PythonServerError } from '../errors';

// ============================================================================
// Schemas
// ============================================================================

export const ExecuteRequest = Schema.Struct({
  code: Schema.Array(Schema.String),
  language: Schema.Literal('python', 'sql'),
});
export type ExecuteRequest = typeof ExecuteRequest.Type;

export const ExecuteResult = Schema.Struct({
  outputs: Schema.String,
});
export type ExecuteResult = typeof ExecuteResult.Type;

export const EnvironmentCreateRequest = Schema.Struct({
  chatId: Schema.String,
  dataset: Schema.String,
});
export type EnvironmentCreateRequest = typeof EnvironmentCreateRequest.Type;

export const EnvironmentCreateResponse = Schema.Struct({
  available_dataframes: Schema.String,
});
export type EnvironmentCreateResponse = typeof EnvironmentCreateResponse.Type;

// ============================================================================
// Service
// ============================================================================

export class PythonServer extends Effect.Service<PythonServer>()('app/PythonServer', {
  effect: Effect.gen(function* () {
    const config = yield* Config;
    const baseUrl = config.pythonServerUrl;

    yield* Effect.logInfo(`PythonServer service initialized with URL: ${baseUrl}`);

    // Helper for making fetch requests with proper error handling
    const fetchJson = <T>(
      path: string,
      options: RequestInit,
      schema: Schema.Schema<T>,
    ): Effect.Effect<T, PythonServerError> =>
      Effect.gen(function* () {
        const response = yield* Effect.tryPromise({
          try: () =>
            fetch(`${baseUrl}${path}`, {
              ...options,
              headers: {
                'Content-Type': 'application/json',
                ...options.headers,
              },
            }),
          catch: (error) =>
            new PythonServerError({
              message: `Failed to connect to Python server: ${error instanceof Error ? error.message : String(error)}`,
            }),
        });

        if (!response.ok) {
          const errorText = yield* Effect.tryPromise({
            try: () => response.text(),
            catch: () => new PythonServerError({ message: 'Failed to read error response' }),
          });
          return yield* Effect.fail(
            new PythonServerError({
              message: `Python server error (${response.status}): ${errorText}`,
            }),
          );
        }

        const json = yield* Effect.tryPromise({
          try: () => response.json(),
          catch: (error) =>
            new PythonServerError({
              message: `Failed to parse JSON response: ${error instanceof Error ? error.message : String(error)}`,
            }),
        });

        return yield* Schema.decodeUnknown(schema)(json).pipe(
          Effect.mapError(
            (error) =>
              new PythonServerError({
                message: `Invalid response schema: ${String(error)}`,
              }),
          ),
        );
      });

    /**
     * List available datasets
     */
    const listDatasets = Effect.tryPromise({
      try: () => fetch(`${baseUrl}/dataset/list`).then((res) => res.json() as Promise<string[]>),
      catch: (error) =>
        new PythonServerError({
          message: `Failed to list datasets: ${error instanceof Error ? error.message : String(error)}`,
        }),
    }).pipe(Effect.withSpan('PythonServer.listDatasets'));

    /**
     * Create or get an execution environment for a chat
     */
    const createEnvironment = (chatId: string, dataset: string) =>
      fetchJson(
        '/environment/create',
        {
          method: 'POST',
          body: JSON.stringify({ chat_id: chatId, dataset }),
        },
        EnvironmentCreateResponse,
      ).pipe(
        Effect.withSpan('PythonServer.createEnvironment', { attributes: { chatId, dataset } }),
      );

    /**
     * Execute code in a chat's environment
     */
    const execute = (chatId: string, code: string[], language: 'python' | 'sql') =>
      fetchJson(
        '/execute',
        {
          method: 'POST',
          body: JSON.stringify({ chat_id: chatId, code, language }),
        },
        ExecuteResult,
      ).pipe(
        Effect.withSpan('PythonServer.execute', {
          attributes: { chatId, language, codeLines: code.length },
        }),
      );

    /**
     * Destroy an execution environment
     */
    const destroyEnvironment = (chatId: string) =>
      Effect.tryPromise({
        try: () =>
          fetch(`${baseUrl}/environment/destroy`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ chat_id: chatId }),
          }),
        catch: (error) =>
          new PythonServerError({
            message: `Failed to destroy environment: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(
        Effect.asVoid,
        Effect.withSpan('PythonServer.destroyEnvironment', { attributes: { chatId } }),
      );

    /**
     * Check if an environment exists for a chat
     */
    const environmentExists = (chatId: string) =>
      Effect.tryPromise({
        try: () =>
          fetch(`${baseUrl}/environment/exists?chat_id=${encodeURIComponent(chatId)}`).then(
            (res) => res.json() as Promise<boolean>,
          ),
        catch: (error) =>
          new PythonServerError({
            message: `Failed to check environment: ${error instanceof Error ? error.message : String(error)}`,
          }),
      }).pipe(Effect.withSpan('PythonServer.environmentExists', { attributes: { chatId } }));

    return {
      listDatasets,
      createEnvironment,
      execute,
      destroyEnvironment,
      environmentExists,
    } as const;
  }),
  dependencies: [Config.Default],
}) {}

export const PythonServerLive = PythonServer.Default;
