import { Effect, Match, Option } from 'effect';
import { Database } from '../services/Database';
import * as T from '$lib/server/db/schema';
import { eq, and, desc, asc } from 'drizzle-orm';
import { AuthError, DatabaseError } from '../errors';

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
    Effect.withSpan('postgresql SELECT chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'select',
        'db.sql.table': 'chat',
      },
    }),
  );

/**
 * Ensure a chat is owned by the current user.
 */
export const requireChatOwnership = (userId: string, chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;
    const chatResult = yield* db.query.chat.findFirst({
      where: and(eq(T.chat.userId, userId), eq(T.chat.id, chatId)),
    });

    if (!chatResult) {
      return yield* Effect.fail(
        new AuthError({ message: `user (${userId}) does not own chat (${chatId})` }),
      );
    }

    return chatResult;
  }).pipe(
    Effect.mapError((error) => {
      if (error instanceof AuthError) {
        return error;
      }
      return new DatabaseError({
        message: `Failed to verify chat ownership: ${error instanceof Error ? error.message : String(error)}`,
      });
    }),
    Effect.withSpan('postgresql SELECT chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'select',
        'db.sql.table': 'chat',
      },
    }),
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
    Effect.withSpan('postgresql INSERT chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'insert',
        'db.sql.table': 'chat',
      },
    }),
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
    Effect.withSpan('postgresql DELETE chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'delete',
        'db.sql.table': 'chat',
      },
    }),
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
    Effect.withSpan('postgresql INSERT message_requests', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'insert',
        'db.sql.table': 'message_requests',
      },
    }),
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
    Effect.withSpan('postgresql UPDATE chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'update',
        'db.sql.table': 'chat',
      },
    }),
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
    Effect.withSpan('postgresql UPDATE chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'update',
        'db.sql.table': 'chat',
      },
    }),
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
    Effect.withSpan('postgresql SELECT message_requests', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'select',
        'db.sql.table': 'message_requests',
      },
    }),
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
  toolCallId?: string;
}

export interface ChatHistory {
  currentMessageRequest: string | null;
  currentMessageRequestContent: string | null;
  messages: DisplayMessage[];
}

/**
 * Get chat with history from normalized tables (chatMessage + chatMessagePart).
 * Transforms the data into the display format expected by the frontend.
 */
export const getChatWithHistory = (userId: string, chatId: string) =>
  Effect.gen(function* () {
    const db = yield* Database;

    const chat = yield* db.query.chat.findFirst({
      where: and(eq(T.chat.userId, userId), eq(T.chat.id, chatId)),
      with: {
        currentMessageRequestRecord: true,
        messages: {
          orderBy: [asc(T.chatMessage.sequence)],
          with: {
            parts: {
              orderBy: [asc(T.chatMessagePart.sequence)],
            },
          },
        },
      },
    });

    if (!chat) {
      return Option.none<ChatHistory>();
    }

    const currentMessageRequest = chat.currentMessageRequest ?? null;
    const currentMessageRequestContent = chat.currentMessageRequestRecord?.content ?? null;

    if (chat.messages.length === 0) {
      return Option.some({
        currentMessageRequest,
        currentMessageRequestContent,
        messages: [] as DisplayMessage[],
      });
    }

    const toolResultMap = new Map<string, T.ToolResultPartContent>();
    for (const msg of chat.messages) {
      for (const part of msg.parts) {
        if (part.type === 'tool-result') {
          const content = part.content as T.ToolResultPartContent;
          toolResultMap.set(content.id, content);
        }
      }
    }

    type MessagePart = (typeof chat.messages)[number]['parts'][number];

    const partToDisplayMessage = (
      msgRole: 'system' | 'user' | 'assistant' | 'tool',
      part: MessagePart,
    ) =>
      Match.value(part).pipe(
        Match.when(
          (value): value is MessagePart & { type: 'text' } => value.type === 'text',
          (value) =>
            Option.some({
              role: msgRole as 'user' | 'assistant',
              content: (value.content as T.TextPartContent).text,
            }),
        ),
        Match.when(
          (value): value is MessagePart & { type: 'tool-call' } => value.type === 'tool-call',
          (value) => {
            const content = value.content as T.ToolCallPartContent;
            const toolResult = toolResultMap.get(content.id);
            return Option.some({
              role: 'tool' as const,
              name: content.name,
              arguments:
                typeof content.params === 'string'
                  ? content.params
                  : JSON.stringify(content.params),
              output: toolResult?.result,
              toolCallId: content.id,
            });
          },
        ),
        Match.orElse(() => Option.none()),
      );

    const messages: DisplayMessage[] = [];

    for (const msg of chat.messages) {
      if (msg.role === 'system') {
        continue;
      }

      for (const part of msg.parts) {
        const displayMessage = partToDisplayMessage(msg.role, part);
        if (Option.isSome(displayMessage)) {
          messages.push(displayMessage.value);
        }
      }
    }

    return Option.some({
      currentMessageRequest,
      currentMessageRequestContent,
      messages,
    });
  }).pipe(
    Effect.mapError(
      (error) =>
        new DatabaseError({
          message: `Failed to get chat with history: ${error instanceof Error ? error.message : String(error)}`,
        }),
    ),
    Effect.withSpan('postgresql SELECT chat', {
      attributes: {
        'db.system': 'postgresql',
        'db.operation': 'select',
        'db.sql.table': 'chat',
      },
    }),
  );
