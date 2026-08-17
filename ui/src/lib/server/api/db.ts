import { Effect, Match, Option } from 'effect';
import { Database } from '../services/Database';
import * as T from '$lib/server/db/schema';
import { eq, and, desc, asc, isNull } from 'drizzle-orm';
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
      .where(and(eq(T.chat.userId, userId), isNull(T.chat.deletedAt)))
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
      where: and(eq(T.chat.userId, userId), eq(T.chat.id, chatId), isNull(T.chat.deletedAt)),
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
