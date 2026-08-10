import { Effect, Option, Redacted } from 'effect';
import { Environment } from './Environment';

export class Config extends Effect.Service<Config>()('app/Config', {
  effect: Effect.gen(function* () {
    const env = yield* Environment;
    return {
      authSecret: Redacted.make(env.AUTH_SECRET),
      internalCellSecret: Redacted.make(env.INTERNAL_CELL_SECRET),
      openaiApiKey: Option.fromNullable(env.OPENAI_API_KEY),
      openaiModel: Option.fromNullable(env.OPENAI_MODEL),
      liveOrigin: env.LIVE_ORIGIN,
      internalApiUrl: env.INTERNAL_API_URL,
      internalProjectionSecret: Redacted.make(env.INTERNAL_PROJECTION_SECRET),
      pythonServerUrl: env.PYTHON_SERVER_URL,
    } as const;
  }),
}) {}

export const ConfigLive = Config.Default;
