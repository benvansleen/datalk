import { Effect, Config as EffectConfig, Redacted } from 'effect';

export class Config extends Effect.Service<Config>()('Config', {
  effect: Effect.gen(function* () {
    const dbUser = yield* EffectConfig.string('DB_USER');
    const dbPassword = yield* EffectConfig.redacted('DB_PASSWORD');
    const dbHost = yield* EffectConfig.string('DB_HOST');
    const dbPort = yield* EffectConfig.string('DB_PORT');
    const dbName = yield* EffectConfig.string('DB_NAME');
    const internalProjectionSecret = yield* EffectConfig.redacted('INTERNAL_PROJECTION_SECRET');
    const pythonServerHost = yield* EffectConfig.string('PYTHON_SERVER_HOST');
    const pythonServerPort = yield* EffectConfig.string('PYTHON_SERVER_PORT');
    const environment = yield* EffectConfig.string('ENVIRONMENT').pipe(
      EffectConfig.withDefault('development'),
    );

    // Build URLs - Note: Redacted for password keeps it out of logs
    const dbPasswordValue = Redacted.value(dbPassword);

    return {
      databaseUrl: Redacted.make(
        `postgres://${dbUser}:${dbPasswordValue}@${dbHost}:${dbPort}/${dbName}?sslmode=disable`,
      ),
      pythonServerUrl: `http://${pythonServerHost}:${pythonServerPort}`,
      internalProjectionSecret,
      environment,
      isProduction: environment === 'production',
      whitelistedEmails: new Set(['test@gmail.com']),
    } as const;
  }),
}) {}

export const ConfigLive = Config.Default;
