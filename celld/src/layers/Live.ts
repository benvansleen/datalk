import { Layer } from 'effect';
import { AgentLive } from '../services/Agent';
import { AuthLive } from '../services/Auth';
import { ConfigLive } from '../services/Config';
import { InternalApiLive } from '../services/InternalApi';
import { ProjectionLive } from '../services/Projection';
import { PythonServerLive } from '../services/PythonServer';
import { RouterLive } from '../services/Router';
import { HttpLive } from '../services/Http';

export const LiveLayer = Layer.mergeAll(
  AgentLive,
  AuthLive,
  ConfigLive,
  HttpLive,
  InternalApiLive,
  ProjectionLive,
  PythonServerLive,
  RouterLive,
);

export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
