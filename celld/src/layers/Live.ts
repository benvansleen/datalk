import { Layer } from 'effect';
import { AgentLive } from '../services/Agent';
import { AiTelemetryLive } from '../services/AiTelemetry';
import { AuthLive } from '../services/Auth';
import { ConfigLive } from '../services/Config';
import { InternalApiLive } from '../services/InternalApi';
import { ObservabilityLive } from '../services/Observability';
import { ProjectionLive } from '../services/Projection';
import { PythonServerLive } from '../services/PythonServer';
import { RouterLive } from '../services/Router';
import { HttpLive } from '../services/Http';

export const LiveLayer = Layer.mergeAll(
  AgentLive,
  AiTelemetryLive,
  AuthLive,
  ConfigLive,
  HttpLive,
  InternalApiLive,
  ObservabilityLive,
  ProjectionLive,
  PythonServerLive,
  RouterLive,
);

export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
