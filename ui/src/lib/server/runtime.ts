import { ManagedRuntime, Effect, Exit, Cause } from 'effect';
import type { ConfigError as EffectConfigError } from 'effect';
import { type SqlError } from '@effect/sql/SqlError';
import { Tracer } from '@effect/opentelemetry';
import { ROOT_CONTEXT, trace, type SpanContext, type TextMapGetter } from '@opentelemetry/api';
import { W3CTraceContextPropagator } from '@opentelemetry/core';
import { LiveLayer, type AppServices } from './layers/Live';

// Type for the runtime including potential layer construction errors
type RuntimeError = EffectConfigError.ConfigError | SqlError;

// Singleton runtime - initialized once at server startup
// ManagedRuntime handles resource lifecycle automatically
let _runtime: ManagedRuntime.ManagedRuntime<AppServices, RuntimeError> | null = null;

const traceContextPropagator = new W3CTraceContextPropagator();
const headersGetter: TextMapGetter<Headers> = {
  get: (headers, key) => headers.get(key) ?? undefined,
  keys: (headers) => Array.from(headers.keys()),
};

export type RequestSpan = {
  name: string;
  attributes?: Record<string, unknown>;
  parent?: SpanContext;
};

export const requestSpanFromRequest = (request: Request, url: URL, route?: string): RequestSpan => {
  const normalizedRoute = route ?? url.pathname;
  const context = traceContextPropagator.extract(ROOT_CONTEXT, request.headers, headersGetter);
  return {
    name: `${request.method} ${normalizedRoute}`,
    attributes: {
      'http.method': request.method,
      'http.route': normalizedRoute,
      'http.url': url.toString(),
    },
    parent: trace.getSpanContext(context),
  };
};

const withTraceLogAnnotations = <A, E, R>(effect: Effect.Effect<A, E, R>): Effect.Effect<A, E, R> =>
  Effect.currentSpan.pipe(
    Effect.flatMap((span) =>
      effect.pipe(Effect.annotateLogs({ traceId: span.traceId, spanId: span.spanId })),
    ),
    Effect.catchAll(() => effect),
  );

export const withRequestSpan = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
  span?: RequestSpan,
): Effect.Effect<A, E, R> => {
  if (!span) return effect;
  const traced = effect.pipe(Effect.withSpan(span.name, { attributes: span.attributes }));
  return span.parent ? traced.pipe(Tracer.withSpanContext(span.parent)) : traced;
};

const withRequestSpanAndLogs = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
  span?: RequestSpan,
): Effect.Effect<A, E, R> => withRequestSpan(withTraceLogAnnotations(effect), span);

const withEffectConfig = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
  span?: RequestSpan,
): Effect.Effect<A, E, R> =>
  withRequestSpanAndLogs(effect, span).pipe(Effect.withConcurrency('unbounded'));

export const getRuntime = (): ManagedRuntime.ManagedRuntime<AppServices, RuntimeError> => {
  if (!_runtime) {
    _runtime = ManagedRuntime.make(LiveLayer);
    _runtime.runFork(
      withRequestSpanAndLogs(Effect.logInfo('Runtime startup'), { name: 'app.startup' }),
    );
  }
  return _runtime;
};

// Helper to run Effects in route handlers - returns a Promise
export const runEffect = <A, E>(
  effect: Effect.Effect<A, E, AppServices>,
  span?: RequestSpan,
): Promise<A> => getRuntime().runPromise(withEffectConfig(effect, span));

// Helper to run Effects and get the Exit value (success or failure)
export const runEffectExit = <A, E>(
  effect: Effect.Effect<A, E, AppServices>,
  span?: RequestSpan,
): Promise<Exit.Exit<A, E | RuntimeError>> =>
  getRuntime().runPromiseExit(withEffectConfig(effect, span));

// Helper to fork Effects with automatic error logging
// Forked effects run in the background - errors are logged but don't propagate
export const runEffectFork = <A, E>(effect: Effect.Effect<A, E, AppServices>, span?: RequestSpan) =>
  getRuntime().runFork(
    withEffectConfig(
      effect.pipe(
        Effect.tapErrorCause((cause) =>
          Effect.logError('Forked effect failed', Cause.pretty(cause)),
        ),
        Effect.catchAllCause(() => Effect.void),
      ),
      span,
    ),
  );
