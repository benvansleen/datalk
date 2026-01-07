// Services
export { Config, ConfigLive } from './services/Config';
export { Auth, AuthLive } from './services/Auth';
export { Redis, RedisLive } from './services/Redis';
export { Database, DatabaseLive } from './services/Database';
export { PythonServer, PythonServerLive } from './services/PythonServer';

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

// API functions - Auth
export { effectSignup, effectLogin, effectSignout } from './api/auth';

// API functions - Chat
export {
  publishChatStatus,
  publishGenerationEvent,
  markGenerationComplete,
  getGenerationHistory,
  subscribeChatStatus,
  subscribeGenerationEvents,
  type ChatStatusEvent,
  type GenerationEvent,
} from './api/chat';

// API functions - Auth check
export { requireAuthEffect, getAuthEffect, requireOwnership } from './api/auth-check';

// SSE utilities
export { streamToSSE, withHeartbeat } from './sse';

// Redis subscriber service
export { RedisSubscriber, RedisSubscriberLive } from './services/RedisSubscriber';

// API functions - Database
export {
  getChatsForUser,
  createChat,
  deleteChat,
  getChatWithMessages,
  createMessageRequest,
  updateChatTitle,
  clearCurrentMessageRequest,
  getMessageRequest,
} from './api/db';

// API functions - Python Server
export {
  listDatasets,
  createEnvironment,
  executePython,
  executeSql,
  destroyEnvironment,
  environmentExists,
} from './api/python';
