// Services
export { Config, ConfigLive } from './services/Config';
export { Auth, AuthLive } from './services/Auth';
export { DatabaseLive, Database, PgDrizzle } from './services/Database';

// Schemas
export { SignupRequest, LoginRequest } from './schemas/auth';

// Errors
export {
  DatabaseError,
  ConfigError,
  AuthError,
  WhitelistError,
  RedisError,
  PythonServerError,
} from './errors';

// Layers
export { LiveLayer, type AppServices } from './layers/Live';
// TestLayer is a placeholder - will be expanded when we add @effect/vitest

// Runtime
export { getRuntime, runEffect, runEffectExit, getFailure } from './runtime';

// Observability
export { ObservabilityLive } from './observability';

// API functions
export { effectSignup, effectLogin, effectSignout } from './api/auth';
