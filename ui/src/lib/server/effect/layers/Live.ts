import { Effect, Layer, Redacted } from 'effect';
import { Auth } from '../services/Auth';
import { ChatTitleGenerator } from '../services/ChatTitleGenerator';
import { Config } from '../services/Config';
import { DatabaseLive } from '../services/Database';
import { ObservabilityLive } from '../observability';
import { PythonServer } from '../services/PythonServer';
import { Redis } from '../services/Redis';
import { RedisSubscriber } from '../services/RedisSubscriber';
import { OpenAiClient } from '@effect/ai-openai';
import { NodeHttpClient } from '@effect/platform-node';

// OpenAI client layer - requires Config for API key and HttpClient
const OpenAiClientLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    const config = yield* Config;
    return OpenAiClient.layer({ apiKey: config.openaiApiKey });
  })
);

export const LiveLayer = Layer.mergeAll(
  Auth.Default,
  DatabaseLive,
  ObservabilityLive,
  PythonServer.Default,
  Redis.Default,
  RedisSubscriber.Default,
  ChatTitleGenerator.Default,
).pipe(
  Layer.provide(OpenAiClientLive.pipe(Layer.provide(NodeHttpClient.layerUndici))),
  Layer.provideMerge(Config.Default),
);

// Type helper for the services provided by the live layer
export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
