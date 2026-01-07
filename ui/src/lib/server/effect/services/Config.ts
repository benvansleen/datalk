import { Effect, Config as EffectConfig, Redacted } from 'effect';

export class Config extends Effect.Service<Config>()('Config', {
  effect: Effect.gen(function* () {
    const dbUser = yield* EffectConfig.string('DB_USER');
    const dbPassword = yield* EffectConfig.redacted('DB_PASSWORD');
    const dbHost = yield* EffectConfig.string('DB_HOST');
    const dbPort = yield* EffectConfig.string('DB_PORT');
    const dbName = yield* EffectConfig.string('DB_NAME');
    const redisUser = yield* EffectConfig.string('REDIS_USER').pipe(
      EffectConfig.withDefault('default'),
    );
    const redisPassword = yield* EffectConfig.redacted('REDIS_PASSWORD');
    const redisHost = yield* EffectConfig.string('REDIS_HOST');
    const redisPort = yield* EffectConfig.string('REDIS_PORT');
    const pythonServerHost = yield* EffectConfig.string('PYTHON_SERVER_HOST');
    const pythonServerPort = yield* EffectConfig.string('PYTHON_SERVER_PORT');
    const environment = yield* EffectConfig.string('ENVIRONMENT').pipe(
      EffectConfig.withDefault('development'),
    );

    // Build URLs - Note: Redacted for password keeps it out of logs
    const dbPasswordValue = Redacted.value(dbPassword);
    const redisPasswordValue = Redacted.value(redisPassword);

    const openaiApiKey = yield* EffectConfig.redacted('OPENAI_API_KEY');

    return {
      databaseUrl: Redacted.make(`postgres://${dbUser}:${dbPasswordValue}@${dbHost}:${dbPort}/${dbName}?sslmode=disable`),
      redisUrl: Redacted.make(`redis://${redisUser}:${redisPasswordValue}@${redisHost}:${redisPort}`),
      pythonServerUrl: `http://${pythonServerHost}:${pythonServerPort}`,
      environment,
      isProduction: environment === 'production',
      openaiApiKey,
    } as const;
  }),
}) {}

export const ConfigLive = Config.Default;
