import { Schema } from 'effect';

// Base database error
export class DatabaseError extends Schema.TaggedError<DatabaseError>()('DatabaseError', {
  message: Schema.String,
  cause: Schema.optional(Schema.Defect),
}) {}

export class ChatError extends Schema.TaggedError<ChatError>()('ChatError', {
  message: Schema.String,
  cause: Schema.optional(Schema.Defect),
}) {}

// Configuration error
export class ConfigError extends Schema.TaggedError<ConfigError>()('ConfigError', {
  message: Schema.String,
  cause: Schema.optional(Schema.Defect),
}) {}

// Auth errors
export class AuthError extends Schema.TaggedError<AuthError>()('AuthError', {
  message: Schema.String,
  code: Schema.optional(Schema.String),
}) {}

export class WhitelistError extends Schema.TaggedError<WhitelistError>()('WhitelistError', {
  message: Schema.String,
}) {}

// Redis errors (for Phase 2)
export class RedisError extends Schema.TaggedError<RedisError>()('RedisError', {
  message: Schema.String,
  cause: Schema.optional(Schema.Defect),
}) {}

// Python server errors (for Phase 2)
export class PythonServerError extends Schema.TaggedError<PythonServerError>()(
  'PythonServerError',
  {
    message: Schema.String,
    cause: Schema.optional(Schema.Defect),
  },
) {}
