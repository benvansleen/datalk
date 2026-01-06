import { Layer } from 'effect';
import { Config } from '../services/Config';
import { Auth } from '../services/Auth';
import { ObservabilityLive } from '../observability';

// Compose all production layers
// Auth.Default already depends on Config.Default, so we just need to provide Config once
export const LiveLayer = Layer.mergeAll(Auth.Default, ObservabilityLive).pipe(
  Layer.provide(Config.Default),
);

// Type helper for the services provided by the live layer
export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
