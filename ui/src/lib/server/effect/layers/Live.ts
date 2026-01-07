import { Layer } from 'effect';
import { Config } from '../services/Config';
import { Auth } from '../services/Auth';
import { Redis } from '../services/Redis';
import { DatabaseLive } from '../services/Database';
import { PythonServer } from '../services/PythonServer';
import { ObservabilityLive } from '../observability';

// Compose all production layers
// Auth.Default, Redis.Default, and PythonServer.Default already depend on Config.Default
// DatabaseLive provides PgDrizzle for database operations
export const LiveLayer = Layer.mergeAll(
  Auth.Default,
  Redis.Default,
  DatabaseLive,
  PythonServer.Default,
  ObservabilityLive,
).pipe(Layer.provide(Config.Default));

// Type helper for the services provided by the live layer
export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
