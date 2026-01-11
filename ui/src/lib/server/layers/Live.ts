import { Effect, Layer, Logger } from 'effect';
import { Auth } from '../services/Auth';
import { ChatTitleGenerator } from '../services/ChatTitleGenerator';
import { Config } from '../services/Config';
import { DatabaseLive } from '../services/Database';
import { ObservabilityLive } from '../observability';
import { PythonServer } from '../services/PythonServer';
import { Redis } from '../services/Redis';
import { RedisSubscriber } from '../services/RedisSubscriber';
import { DatalkAgent } from '../services/DatalkAgent';
import { OpenAiClient } from '@effect/ai-openai';
import { NodeHttpClient } from '@effect/platform-node';

// OpenAI client layer - requires Config for API key and HttpClient
const OpenAiClientLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    const config = yield* Config;
    return OpenAiClient.layer({ apiKey: config.openaiApiKey });
  }),
);

// DatalkAgent needs Database, so we provide it here
const DatalkAgentWithDeps = DatalkAgent.Default.pipe(Layer.provide(DatabaseLive));

export const LiveLayer = Layer.mergeAll(
  Auth.Default,
  DatabaseLive,
  ObservabilityLive,
  PythonServer.Default,
  Redis.Default,
  RedisSubscriber.Default,
  ChatTitleGenerator.Default,
  DatalkAgentWithDeps,
).pipe(
  Layer.provide(OpenAiClientLive.pipe(Layer.provide(NodeHttpClient.layerUndici))),
  Layer.provideMerge(Config.Default),
  Layer.provide(Logger.logFmt),
);

// Type helper for the services provided by the live layer
export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
