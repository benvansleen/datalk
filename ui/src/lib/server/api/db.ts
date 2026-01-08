import { Effect, Option } from 'effect';
import { Database } from '../services/Database';
import * as T from '$lib/server/db/schema';
import { eq, and, desc } from 'drizzle-orm';
import { DatabaseError } from '../errors';

/**
 * Get all chats for a user, ordered by most recently updated
 */
export const getChatsForUser = (userId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    return yield* db
      .select()
      .from(T.chat)
      .where(eq(T.chat.userId, userId))
      .orderBy(desc(T.chat.updatedAt));
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to get chats: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.getChatsForUser'),
  );

/**
 * Create a new chat and return its ID
 */
export const createChat = (userId: string, dataset: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    const [result] = yield* db
      .insert(T.chat)
      .values({
        userId,
        dataset,
        title: '...',
        currentMessageRequest: null,
      })
      .returning({ chatId: T.chat.id });
    return result.chatId;
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to create chat: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.createChat'),
  );

/**
 * Delete a chat owned by a user
 */
export const deleteChat = (userId: string, chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    yield* db.delete(T.chat).where(and(eq(T.chat.userId, userId), eq(T.chat.id, chatId)));
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to delete chat: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.deleteChat'),
  );

/**
 * Get a chat with all related messages and function calls using relational query
 */
export const getChatWithMessages = (userId: string, chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    const result = yield* db.query.chat.findFirst({
      where: and(eq(T.chat.userId, userId), eq(T.chat.id, chatId)),
      with: {
        messages: { with: { messageContents: true } },
        functionCalls: true,
        functionResults: true,
      },
    });
    return Option.fromNullable(result);
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to get chat with messages: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.getChatWithMessages'),
  );

/**
 * Insert a message request
 */
export const createMessageRequest = (userId: string, chatId: string, content: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    const [result] = yield* db
      .insert(T.messageRequests)
      .values({ userId, chatId, content })
      .returning({ messageRequestId: T.messageRequests.id });
    return result.messageRequestId;
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to create message request: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.createMessageRequest'),
  );

/**
 * Update chat title
 */
export const updateChatTitle = (chatId: string, title: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    yield* db.update(T.chat).set({ title }).where(eq(T.chat.id, chatId));
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to update chat title: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.updateChatTitle'),
  );

/**
 * Clear current message request on chat
 */
export const clearCurrentMessageRequest = (chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    yield* db.update(T.chat).set({ currentMessageRequest: null }).where(eq(T.chat.id, chatId));
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to clear message request: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.clearCurrentMessageRequest'),
  );

/**
 * Get a message request by ID
 */
export const getMessageRequest = (messageRequestId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    const [result] = yield* db
      .select()
      .from(T.messageRequests)
      .where(eq(T.messageRequests.id, messageRequestId))
      .limit(1);
    return Option.fromNullable(result);
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to get message request: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.getMessageRequest'),
  );

// ============================================================================
// Chat History (@effect/ai Prompt format)
// ============================================================================

/**
 * Type definitions for the @effect/ai Prompt format stored in chat_history.
 * These mirror the encoded format from @effect/ai/Prompt.
 */

interface TextPartEncoded {
  readonly type: 'text';
  readonly text: string;
  readonly options?: Record<string, unknown>;
}

interface ToolCallPartEncoded {
  readonly type: 'tool-call';
  readonly id: string;
  readonly name: string;
  readonly params: unknown;
  readonly providerExecuted?: boolean;
  readonly options?: Record<string, unknown>;
}

interface ToolResultPartEncoded {
  readonly type: 'tool-result';
  readonly id: string;
  readonly name: string;
  readonly isFailure: boolean;
  readonly result: unknown;
  readonly providerExecuted: boolean;
  readonly options?: Record<string, unknown>;
}

type PartEncoded = TextPartEncoded | ToolCallPartEncoded | ToolResultPartEncoded;

interface MessageEncoded {
  readonly role: 'system' | 'user' | 'assistant' | 'tool';
  readonly content: string | ReadonlyArray<PartEncoded>;
  readonly options?: Record<string, unknown>;
}

interface PromptEncoded {
  readonly content: ReadonlyArray<MessageEncoded>;
}

/**
 * Display message format expected by the frontend.
 */
export interface DisplayMessage {
  role: 'user' | 'assistant' | 'tool';
  content?: string;
  name?: string;
  arguments?: string;
  output?: unknown;
}

/**
 * Get chat with history from the new chat_history table.
 * Transforms the @effect/ai Prompt format into the display format expected by the frontend.
 */
export const getChatWithHistory = (userId: string, chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;

    // First, get the chat to verify ownership
    const chatResult = yield* db.query.chat.findFirst({
      where: and(eq(T.chat.userId, userId), eq(T.chat.id, chatId)),
    });

    if (!chatResult) {
      return Option.none<{ currentMessageRequest: string | null; messages: DisplayMessage[] }>();
    }

    // Get the chat history from the new table
    const historyResult = yield* db.query.chatHistory.findFirst({
      where: and(eq(T.chatHistory.chatId, chatId), eq(T.chatHistory.storeId, 'datalk-chats')),
    });

    if (!historyResult) {
      // No history yet, return empty messages
      return Option.some({
        currentMessageRequest: chatResult.currentMessageRequest,
        messages: [] as DisplayMessage[],
      });
    }

    // Parse the stored Prompt format
    const prompt = historyResult.history as PromptEncoded;
    const messages: DisplayMessage[] = [];

    for (const message of prompt.content) {
      // Skip system messages - they're not shown to the user
      if (message.role === 'system') {
        continue;
      }

      // Handle string content (simple text message)
      if (typeof message.content === 'string') {
        messages.push({
          role: message.role as 'user' | 'assistant',
          content: message.content,
        });
        continue;
      }

      // Handle array content (parts)
      for (const part of message.content) {
        switch (part.type) {
          case 'text': {
            messages.push({
              role: message.role as 'user' | 'assistant',
              content: part.text,
            });
            break;
          }

          case 'tool-call': {
            // Find the corresponding tool result in the same message or subsequent messages
            const toolResult = findToolResult(prompt.content, part.id);
            messages.push({
              role: 'tool',
              name: part.name,
              arguments: typeof part.params === 'string' ? part.params : JSON.stringify(part.params),
              output: toolResult?.result,
            });
            break;
          }

          // tool-result parts are handled when we process tool-call parts
          case 'tool-result':
            break;
        }
      }
    }

    return Option.some({
      currentMessageRequest: chatResult.currentMessageRequest,
      messages,
    });
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to get chat with history: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('db.getChatWithHistory'),
  );

/**
 * Helper to find a tool result by tool call ID in the prompt messages.
 */
function findToolResult(
  messages: ReadonlyArray<MessageEncoded>,
  toolCallId: string,
): ToolResultPartEncoded | undefined {
  for (const message of messages) {
    if (typeof message.content === 'string') continue;

    for (const part of message.content) {
      if (part.type === 'tool-result' && part.id === toolCallId) {
        return part;
      }
    }
  }
  return undefined;
}
