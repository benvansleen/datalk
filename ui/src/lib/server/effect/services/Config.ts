import { Effect, Config as EffectConfig, Redacted, Layer } from 'effect';

export class Config extends Effect.Service<Config>()('Config', {
  effect: Effect.gen(function* () {
    const dbUser = yield* EffectConfig.string('DB_USER');
    const dbPassword = yield* EffectConfig.redacted('DB_PASSWORD');
    const dbHost = yield* EffectConfig.string('DB_HOST');
    const dbPort = yield* EffectConfig.string('DB_PORT');
    const dbName = yield* EffectConfig.string('DB_NAME');
    const redisHost = yield* EffectConfig.string('REDIS_HOST');
    const redisPort = yield* EffectConfig.string('REDIS_PORT');
    const pythonServerHost = yield* EffectConfig.string('PYTHON_SERVER_HOST');
    const pythonServerPort = yield* EffectConfig.string('PYTHON_SERVER_PORT');
    const environment = yield* EffectConfig.string('ENVIRONMENT').pipe(
      EffectConfig.withDefault('development'),
    );

    // Build URLs - Note: Redacted for password keeps it out of logs
    const dbPasswordValue = Redacted.value(dbPassword);

    return {
      databaseUrl: `postgres://${dbUser}:${dbPasswordValue}@${dbHost}:${dbPort}/${dbName}?sslmode=disable`,
      redisUrl: `redis://${redisHost}:${redisPort}`,
      pythonServerUrl: `http://${pythonServerHost}:${pythonServerPort}`,
      environment,
      isProduction: environment === 'production',
    } as const;
  }),
}) {}

// Re-export the default layer for convenience
export const ConfigLive = Config.Default;
