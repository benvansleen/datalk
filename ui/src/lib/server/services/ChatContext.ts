import { Context } from 'effect';

/**
 * Runtime context for chat operations.
 * Provides chatId and dataset to tool handlers during agent execution.
 */
export interface ChatContextData {
  readonly chatId: string;
  readonly dataset: string;
}

/**
 * Context tag for providing chat runtime context to Effect-based tool handlers.
 * This allows tools to access the current chat's ID and dataset without
 * passing them through function parameters.
 */
export class ChatContext extends Context.Tag('app/ChatContext')<ChatContext, ChatContextData>() {}
