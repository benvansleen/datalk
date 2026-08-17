import { Effect, Layer } from 'effect';
import { LiveLayer, type AppServices } from '../../src/layers/Live';
import { Environment } from '../../src/services/Environment';
import type { Env } from '../../src/types';

export const testLayer = (env: Env) =>
  LiveLayer.pipe(Layer.provide(Layer.succeed(Environment, env)));

export const runWithEnv = <A, E>(env: Env, effect: Effect.Effect<A, E, AppServices>): Promise<A> =>
  Effect.runPromise(effect.pipe(Effect.provide(testLayer(env))));
