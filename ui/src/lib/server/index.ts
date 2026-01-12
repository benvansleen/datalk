// Services
export { Config, ConfigLive } from './services/Config';
export { Auth, AuthLive } from './services/Auth';
export { Redis, RedisLive } from './services/Redis';
export { RedisClientFactory, RedisClientFactoryLive } from './services/RedisClientFactory';
export { RedisStreamReader, RedisStreamReaderLive } from './services/RedisStreamReader';
export { Database, DatabaseLive } from './services/Database';
export { PythonServer, PythonServerLive } from './services/PythonServer';
export { DatalkAgent, DatalkAgentLive, type DatalkStreamPart } from './services/DatalkAgent';
export { ChatContext, type ChatContextData } from './services/ChatContext';
export { ChatBackingPersistenceLive } from './services/ChatPersistence';
export { ChatTitleGenerator } from './services/ChatTitleGenerator';
export {
  DatalkToolkit,
  DatalkToolHandlersLive,
  makeDatalkToolHandlers,
  type DatalkTools,
} from './services/DatalkTools';

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
export {
  getRuntime,
  runEffect,
  runEffectExit,
  runEffectFork,
  getFailure,
  requestSpanFromRequest,
  type RequestSpan,
} from './runtime';

// Observability
export { ObservabilityLive } from './observability';

// API functions - Chat
export {
  publishChatStatus,
  publishGenerationEvent,
  markGenerationComplete,
  subscribeChatStatus,
  subscribeGenerationEvents,
  type ChatStatusEvent,
  type GenerationEvent,
} from './api/chat';

// SSE utilities
export { streamToSSE } from './sse';

// Redis subscriber service
export { RedisSubscriber, RedisSubscriberLive } from './services/RedisSubscriber';

// API functions - Database
export {
  getChatsForUser,
  getChatWithHistory,
  requireChatOwnership,
  createChat,
  deleteChat,
  createMessageRequest,
  updateChatTitle,
  clearCurrentMessageRequest,
  getMessageRequest,
} from './api/db';
