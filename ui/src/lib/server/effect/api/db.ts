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
