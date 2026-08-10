import { Schema } from 'effect';

export class HttpError extends Schema.TaggedError<HttpError>()('HttpError', {
  status: Schema.Number,
  message: Schema.String,
}) {}

export const LiveSession = Schema.Struct({
  sub: Schema.String.pipe(Schema.minLength(1)),
  exp: Schema.Number,
  aud: Schema.Literal('datalk-live'),
  iss: Schema.Literal('datalk'),
});
export type LiveSession = typeof LiveSession.Type;

export const CreateChatCommand = Schema.Struct({
  dataset: Schema.String.pipe(Schema.minLength(1)),
});
export type CreateChatCommand = typeof CreateChatCommand.Type;

export const SubmitMessageCommand = Schema.Struct({
  content: Schema.String.pipe(Schema.minLength(1), Schema.maxLength(32_000)),
});
export type SubmitMessageCommand = typeof SubmitMessageCommand.Type;

export const ChatSummary = Schema.Struct({
  id: Schema.String,
  dataset: Schema.String,
  title: Schema.String,
  updatedAt: Schema.Number,
  generating: Schema.Boolean,
});
export type ChatSummary = typeof ChatSummary.Type;

export const ChatMessage = Schema.Struct({
  id: Schema.String,
  role: Schema.Literal('user', 'assistant', 'tool'),
  content: Schema.String,
  createdAt: Schema.Number,
  toolCallId: Schema.optional(Schema.String),
  toolName: Schema.optional(Schema.String),
  toolArguments: Schema.optional(Schema.Unknown),
  toolResult: Schema.optional(Schema.Unknown),
  toolFailed: Schema.optional(Schema.Boolean),
});
export type ChatMessage = typeof ChatMessage.Type;

export const GenerationEvent = Schema.Struct({
  sequence: Schema.Number,
  type: Schema.String,
  data: Schema.Unknown,
  createdAt: Schema.Number,
});
export type GenerationEvent = typeof GenerationEvent.Type;

export const ChatSnapshot = Schema.Struct({
  id: Schema.String,
  userId: Schema.String,
  dataset: Schema.String,
  title: Schema.String,
  deleted: Schema.Boolean,
  generating: Schema.Boolean,
  currentMessageRequestId: Schema.NullOr(Schema.String),
  createdAt: Schema.Number,
  updatedAt: Schema.Number,
  messages: Schema.Array(ChatMessage),
  events: Schema.Array(GenerationEvent),
});
export type ChatSnapshot = typeof ChatSnapshot.Type;

export interface Env {
  AUTH_SECRET: string;
  INTERNAL_CELL_SECRET: string;
  OPENAI_API_KEY?: string;
  OPENAI_MODEL?: string;
  LIVE_ORIGIN: string;
  INTERNAL_API_URL: string;
  INTERNAL_PROJECTION_SECRET: string;
  PYTHON_SERVER_URL: string;
  USER_CELL: DurableObjectNamespace;
  CHAT_CELL: DurableObjectNamespace;
}
