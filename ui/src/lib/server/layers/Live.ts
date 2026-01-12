import { Effect, Layer, Logger } from 'effect';
import { Auth } from '../services/Auth';
import { ChatTitleGenerator } from '../services/ChatTitleGenerator';
import { Config } from '../services/Config';
import { DatabaseLive } from '../services/Database';
import { ObservabilityLive } from '../observability';
import { PythonServer } from '../services/PythonServer';
import { Redis } from '../services/Redis';
import { RedisClientFactory } from '../services/RedisClientFactory';
import { RedisStreamReader } from '../services/RedisStreamReader';
import { RedisSubscriber } from '../services/RedisSubscriber';
import { DatalkAgent } from '../services/DatalkAgent';
import { OpenAiClient } from '@effect/ai-openai';
import { NodeHttpClient } from '@effect/platform-node';

const OpenAiClientLive = Layer.unwrapEffect(
  Effect.gen(function* () {
    const config = yield* Config;
    return OpenAiClient.layer({ apiKey: config.openaiApiKey });
  }),
);

export const LiveLayer = Layer.mergeAll(
  Auth.Default,
  ChatTitleGenerator.Default,
  DatalkAgent.Default,
  ObservabilityLive,
  PythonServer.Default,
  Redis.Default,
  RedisStreamReader.Default,
  RedisSubscriber.Default,
).pipe(
  Layer.provideMerge(OpenAiClientLive.pipe(Layer.provide(NodeHttpClient.layerUndici))),
  Layer.provideMerge(DatabaseLive),
  Layer.provideMerge(Config.Default),
  Layer.provide(RedisClientFactory.Default),
  Layer.provide(Logger.logFmt),
);

// Type helper for the services provided by the live layer
export type AppServices = Layer.Layer.Success<typeof LiveLayer>;
