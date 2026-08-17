import { Schema } from 'effect';

export class HttpError extends Schema.TaggedError<HttpError>()('HttpError', {
  status: Schema.Number,
  message: Schema.String,
}) {}

export const CreateChatCommand = Schema.Struct({
  dataset: Schema.String.pipe(Schema.minLength(1)),
});
export type CreateChatCommand = typeof CreateChatCommand.Type;

export const SubmitMessageCommand = Schema.Struct({
  content: Schema.String.pipe(Schema.minLength(1), Schema.maxLength(32_000)),
});
export type SubmitMessageCommand = typeof SubmitMessageCommand.Type;

export const InitializeCommand = Schema.Struct({
  chatId: Schema.String,
  dataset: Schema.String,
});
export type InitializeCommand = typeof InitializeCommand.Type;

export const ChatSummary = Schema.Struct({
  id: Schema.String,
  dataset: Schema.String,
  title: Schema.String,
  updatedAt: Schema.Number,
  generating: Schema.Boolean,
});
export type ChatSummary = typeof ChatSummary.Type;

export const ToolCall = Schema.Struct({
  toolCallId: Schema.String,
  toolName: Schema.String,
  args: Schema.String,
});
export type ToolCall = typeof ToolCall.Type;

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
  toolCalls: Schema.optional(Schema.Array(ToolCall)),
});
export type ChatMessage = typeof ChatMessage.Type;

export const GenerationEvent = Schema.Struct({
  sequence: Schema.Number,
  type: Schema.String,
  data: Schema.Unknown,
  createdAt: Schema.Number,
});
export type GenerationEvent = typeof GenerationEvent.Type;

export interface Env {
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
