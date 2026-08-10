import { Layer, Logger } from 'effect';
import { Auth } from '../services/Auth';
import { Config } from '../services/Config';
import { DatabaseLive } from '../services/Database';
import { LiveSession } from '../services/LiveSession';
import { ObservabilityLive } from '../observability';

export const LiveLayer = Layer.mergeAll(Auth.Default, LiveSession.Default, ObservabilityLive).pipe(
  Layer.provideMerge(DatabaseLive),
  Layer.provideMerge(Config.Default),
  Layer.provide(Logger.logFmt),
);

export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
