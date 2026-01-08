import { Effect, Option } from 'effect';
import { Database } from '../services/Database';
import * as T from '$lib/server/db/schema';
import { eq, and, desc, asc } from 'drizzle-orm';
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
// Chat History Display
// ============================================================================

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
 * Get chat with history from normalized tables (chatMessage + chatMessagePart).
 * Transforms the data into the display format expected by the frontend.
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

    // Get messages with parts from normalized tables
    const messagesWithParts = yield* db.query.chatMessage.findMany({
      where: eq(T.chatMessage.chatId, chatId),
      orderBy: [asc(T.chatMessage.sequence)],
      with: {
        parts: {
          orderBy: [asc(T.chatMessagePart.sequence)],
        },
      },
    });

    if (messagesWithParts.length === 0) {
      // No history yet, return empty messages
      return Option.some({
        currentMessageRequest: chatResult.currentMessageRequest,
        messages: [] as DisplayMessage[],
      });
    }

    // Build a map of tool call ID -> tool result for quick lookup
    const toolResultMap = new Map<string, T.ToolResultPartContent>();
    for (const msg of messagesWithParts) {
      for (const part of msg.parts) {
        if (part.type === 'tool-result') {
          const content = part.content as T.ToolResultPartContent;
          toolResultMap.set(content.id, content);
        }
      }
    }

    // Transform to display format
    const messages: DisplayMessage[] = [];

    for (const msg of messagesWithParts) {
      // Skip system messages - they're not shown to the user
      if (msg.role === 'system') {
        continue;
      }

      // Handle parts
      for (const part of msg.parts) {
        switch (part.type) {
          case 'text': {
            const content = part.content as T.TextPartContent;
            messages.push({
              role: msg.role as 'user' | 'assistant',
              content: content.text,
            });
            break;
          }

          case 'tool-call': {
            const content = part.content as T.ToolCallPartContent;
            const toolResult = toolResultMap.get(content.id);
            messages.push({
              role: 'tool',
              name: content.name,
              arguments:
                typeof content.params === 'string'
                  ? content.params
                  : JSON.stringify(content.params),
              output: toolResult?.result,
            });
            break;
          }

          // tool-result parts are handled when we process tool-call parts
          case 'tool-result':
          case 'reasoning':
          case 'file':
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
