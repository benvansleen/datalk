import { Tracer as OtelTracer } from '@effect/opentelemetry';
import { context, trace } from '@opentelemetry/api';
import { W3CTraceContextPropagator } from '@opentelemetry/core';
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

const traceContextPropagator = new W3CTraceContextPropagator();

// ============================================================================
// Service
// ============================================================================

export class PythonServer extends Effect.Service<PythonServer>()('app/PythonServer', {
  effect: Effect.gen(function* () {
    const config = yield* Config;
    const baseUrl = config.pythonServerUrl;

    yield* Effect.logInfo(`PythonServer service initialized with URL: ${baseUrl}`);

    const fetchResponse = (
      path: string,
      options: RequestInit,
      connectionError: (error: unknown) => PythonServerError,
    ): Effect.Effect<Response, PythonServerError> => {
      const method = options.method ?? 'GET';
      const url = `${baseUrl}${path}`;

      return Effect.gen(function* () {
        const otelSpan = yield* OtelTracer.currentOtelSpan.pipe(Effect.orDie);
        const headers = new Headers(options.headers);
        traceContextPropagator.inject(trace.setSpan(context.active(), otelSpan), headers, {
          set: (carrier, key, value) => carrier.set(key, value),
        });

        const response = yield* Effect.tryPromise({
          try: () => fetch(url, { ...options, headers }),
          catch: connectionError,
        });
        yield* Effect.annotateCurrentSpan('http.response.status_code', response.status);
        return response;
      }).pipe(
        Effect.withSpan(`HTTP ${method} ${path.split('?')[0]}`, {
          kind: 'client',
          attributes: {
            'http.request.method': method,
            'http.route': path.split('?')[0],
            'url.full': url,
          },
        }),
      );
    };

    // Helper for JSON requests with status and schema validation.
    const fetchJson = <T>(
      path: string,
      options: RequestInit,
      schema: Schema.Schema<T>,
    ): Effect.Effect<T, PythonServerError> =>
      Effect.gen(function* () {
        const response = yield* fetchResponse(
          path,
          {
            ...options,
            headers: new Headers({
              'Content-Type': 'application/json',
              ...Object.fromEntries(new Headers(options.headers)),
            }),
          },
          (error) =>
            new PythonServerError({
              message: `Failed to connect to Python server: ${error instanceof Error ? error.message : String(error)}`,
            }),
        );

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
    const listDatasets = fetchResponse(
      '/dataset/list',
      {},
      (error) =>
        new PythonServerError({
          message: `Failed to list datasets: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ).pipe(
      Effect.flatMap((response) =>
        Effect.tryPromise({
          try: () => response.json() as Promise<string[]>,
          catch: (error) =>
            new PythonServerError({
              message: `Failed to list datasets: ${error instanceof Error ? error.message : String(error)}`,
            }),
        }),
      ),
    );

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
      );

    /**
     * Destroy an execution environment
     */
    const destroyEnvironment = (chatId: string) =>
      fetchResponse(
        '/environment/destroy',
        {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ chat_id: chatId }),
        },
        (error) =>
          new PythonServerError({
            message: `Failed to destroy environment: ${error instanceof Error ? error.message : String(error)}`,
          }),
      ).pipe(Effect.asVoid);

    /**
     * Check if an environment exists for a chat
     */
    const environmentExists = (chatId: string) =>
      fetchResponse(
        `/environment/exists?chat_id=${encodeURIComponent(chatId)}`,
        {},
        (error) =>
          new PythonServerError({
            message: `Failed to check environment: ${error instanceof Error ? error.message : String(error)}`,
          }),
      ).pipe(
        Effect.flatMap((response) =>
          Effect.tryPromise({
            try: () => response.json() as Promise<boolean>,
            catch: (error) =>
              new PythonServerError({
                message: `Failed to check environment: ${error instanceof Error ? error.message : String(error)}`,
              }),
          }),
        ),
      );

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
