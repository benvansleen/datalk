import {
  ManagedRuntime,
  Effect,
  Exit,
  Cause,
  ConfigError as EffectConfigError,
  Layer,
} from 'effect';
import { SqlError } from '@effect/sql/SqlError';
import { LiveLayer, type AppServices } from './layers/Live';
import { RedisError } from './errors';

// Type for the runtime including potential layer construction errors
type RuntimeError = EffectConfigError.ConfigError | RedisError | SqlError;

// Singleton runtime - initialized once at server startup
// ManagedRuntime handles resource lifecycle automatically
let _runtime: ManagedRuntime.ManagedRuntime<AppServices, RuntimeError> | null = null;

export const getRuntime = (): ManagedRuntime.ManagedRuntime<AppServices, RuntimeError> => {
  if (!_runtime) {
    _runtime = ManagedRuntime.make(LiveLayer);
  }
  return _runtime;
};

// Helper to run Effects in route handlers - returns a Promise
export const runEffect = <A, E>(effect: Effect.Effect<A, E, AppServices>): Promise<A> =>
  getRuntime().runPromise(effect);

// Helper to run Effects and get the Exit value (success or failure)
export const runEffectExit = <A, E>(
  effect: Effect.Effect<A, E, AppServices>,
): Promise<Exit.Exit<A, E | RuntimeError>> => getRuntime().runPromiseExit(effect);

// Helper to fork Effects 
export const runEffectFork = <A, E>(
  effect: Effect.Effect<A, E, AppServices>,
) => getRuntime().runFork(effect);

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
