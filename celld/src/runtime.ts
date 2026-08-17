import { Effect, Layer, ManagedRuntime } from 'effect';
import type { Env } from './types';
import { Environment } from './services/Environment';
import { LiveLayer, type AppServices } from './layers/Live';

const runtimes = new WeakMap<Env, ManagedRuntime.ManagedRuntime<AppServices, never>>();

const getRuntime = (env: Env): ManagedRuntime.ManagedRuntime<AppServices, never> => {
  let runtime = runtimes.get(env);
  if (!runtime) {
    runtime = ManagedRuntime.make(LiveLayer.pipe(Layer.provide(Layer.succeed(Environment, env))));
    runtimes.set(env, runtime);
  }
  return runtime;
};

export const runEffect = <A, E>(env: Env, effect: Effect.Effect<A, E, AppServices>) =>
  getRuntime(env).runPromise(effect);
