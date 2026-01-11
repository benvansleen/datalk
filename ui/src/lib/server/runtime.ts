import { ManagedRuntime, Effect, Exit, Cause, ConfigError as EffectConfigError } from 'effect';
import { type SqlError } from '@effect/sql/SqlError';
import { LiveLayer, type AppServices } from './layers/Live';
import { RedisError } from './errors';

// Type for the runtime including potential layer construction errors
type RuntimeError = EffectConfigError.ConfigError | RedisError | SqlError;

// Singleton runtime - initialized once at server startup
// ManagedRuntime handles resource lifecycle automatically
let _runtime: ManagedRuntime.ManagedRuntime<AppServices, RuntimeError> | null = null;

export type RequestSpan = {
  name: string;
  attributes?: Record<string, unknown>;
};

export const requestSpanFromRequest = (request: Request, url: URL, route?: string): RequestSpan => {
  const normalizedRoute = route ?? url.pathname;
  return {
    name: `${request.method} ${normalizedRoute}`,
    attributes: {
      'http.method': request.method,
      'http.route': normalizedRoute,
      'http.url': url.toString(),
    },
  };
};

const withTraceLogAnnotations = <A, E, R>(effect: Effect.Effect<A, E, R>): Effect.Effect<A, E, R> =>
  Effect.currentSpan.pipe(
    Effect.flatMap((span) =>
      effect.pipe(Effect.annotateLogs({ traceId: span.traceId, spanId: span.spanId })),
    ),
    Effect.catchAll(() => effect),
  );

const withRequestSpan = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
  span?: RequestSpan,
): Effect.Effect<A, E, R> =>
  span ? effect.pipe(Effect.withSpan(span.name, { attributes: span.attributes })) : effect;

const withRequestSpanAndLogs = <A, E, R>(
  effect: Effect.Effect<A, E, R>,
  span?: RequestSpan,
): Effect.Effect<A, E, R> => withRequestSpan(withTraceLogAnnotations(effect), span);

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
): Promise<A> => getRuntime().runPromise(withRequestSpanAndLogs(effect, span));

// Helper to run Effects and get the Exit value (success or failure)
export const runEffectExit = <A, E>(
  effect: Effect.Effect<A, E, AppServices>,
  span?: RequestSpan,
): Promise<Exit.Exit<A, E | RuntimeError>> =>
  getRuntime().runPromiseExit(withRequestSpanAndLogs(effect, span));

// Helper to fork Effects with automatic error logging
// Forked effects run in the background - errors are logged but don't propagate
export const runEffectFork = <A, E>(effect: Effect.Effect<A, E, AppServices>, span?: RequestSpan) =>
  getRuntime().runFork(
    withRequestSpanAndLogs(
      effect.pipe(
        Effect.tapErrorCause((cause) =>
          Effect.logError('Forked effect failed', Cause.pretty(cause)),
        ),
        Effect.catchAllCause(() => Effect.void),
      ),
      span,
    ),
  );

// Helper to extract error from Exit for error handling in routes
export const getFailure = <E>(exit: Exit.Exit<unknown, E>): E | null => {
  if (Exit.isFailure(exit)) {
    const cause = exit.cause;
    if (Cause.isFailType(cause)) {
      return cause.error;
    }
  }
  return null;
};
