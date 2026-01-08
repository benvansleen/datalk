import { Effect, Layer, Option, Duration, Scope, Context } from 'effect';
import { Persistence } from '@effect/experimental';
import { eq, and, asc } from 'drizzle-orm';
import { Database } from './Database';
import * as T from '$lib/server/db/schema';

// ============================================================================
// Types for @effect/ai Prompt format
// ============================================================================

interface PromptEncoded {
  readonly content: ReadonlyArray<MessageEncoded>;
}

interface MessageEncoded {
  readonly role: 'system' | 'user' | 'assistant' | 'tool';
  readonly content: string | ReadonlyArray<PartEncoded>;
  readonly options?: Record<string, unknown>;
}

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
  readonly providerExecuted?: boolean;
  readonly options?: Record<string, unknown>;
}

interface ReasoningPartEncoded {
  readonly type: 'reasoning';
  readonly text: string;
  readonly options?: Record<string, unknown>;
}

interface FilePartEncoded {
  readonly type: 'file';
  readonly mediaType: string;
  readonly url?: string;
  readonly data?: string;
  readonly options?: Record<string, unknown>;
}

type PartEncoded =
  | TextPartEncoded
  | ToolCallPartEncoded
  | ToolResultPartEncoded
  | ReasoningPartEncoded
  | FilePartEncoded;

// ============================================================================
// BackingPersistence Implementation
// ============================================================================

/**
 * Creates a BackingPersistenceStore for a given storeId.
 * This implements the key-value interface required by @effect/ai Chat.Persisted.
 * Uses normalized tables for storage.
 */
const makeStore = (
  storeId: string,
  db: Context.Tag.Service<typeof Database>,
): Effect.Effect<Persistence.BackingPersistenceStore, never, Scope.Scope> =>
  Effect.gen(function* () {
    yield* Effect.addFinalizer(() => Effect.void);

    /**
     * Get chat history by reconstructing the Prompt format from normalized tables
     */
    const get = (
      key: string,
    ): Effect.Effect<Option.Option<unknown>, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logDebug(`[ChatPersistence.get] Getting history for ${key}`);

        const messages = yield* Effect.tryPromise({
          try: async () => {
            return await db.query.chatMessage.findMany({
              where: eq(T.chatMessage.chatId, key),
              orderBy: [asc(T.chatMessage.sequence)],
              with: {
                parts: {
                  orderBy: [asc(T.chatMessagePart.sequence)],
                },
              },
            });
          },
          catch: (error) =>
            new Persistence.PersistenceBackingError({
              reason: 'BackingError',
              method: 'get',
              cause: error,
            }),
        });

        if (messages.length === 0) {
          yield* Effect.logDebug(`[ChatPersistence.get] No messages found`);
          return Option.none();
        }

        // Reconstruct the Prompt format
        const prompt: PromptEncoded = {
          content: messages.map((msg) => {
            // System messages have string content
            if (msg.role === 'system') {
              const textPart = msg.parts.find((p) => p.type === 'text');
              return {
                role: msg.role,
                content: textPart ? (textPart.content as T.TextPartContent).text : '',
              } as MessageEncoded;
            }

            // Other messages have array content
            const parts: PartEncoded[] = msg.parts.map((part) => {
              switch (part.type) {
                case 'text': {
                  const content = part.content as T.TextPartContent;
                  return { type: 'text', text: content.text } as TextPartEncoded;
                }
                case 'tool-call': {
                  const content = part.content as T.ToolCallPartContent;
                  return {
                    type: 'tool-call',
                    id: content.id,
                    name: content.name,
                    params: content.params,
                    providerExecuted: content.providerExecuted ?? false,
                  } as ToolCallPartEncoded;
                }
                case 'tool-result': {
                  const content = part.content as T.ToolResultPartContent;
                  return {
                    type: 'tool-result',
                    id: content.id,
                    name: content.name,
                    result: content.result,
                    isFailure: content.isFailure,
                    providerExecuted: content.providerExecuted ?? false,
                  } as ToolResultPartEncoded;
                }
                case 'reasoning': {
                  const content = part.content as T.ReasoningPartContent;
                  return { type: 'reasoning', text: content.text } as ReasoningPartEncoded;
                }
                case 'file': {
                  const content = part.content as T.FilePartContent;
                  return {
                    type: 'file',
                    mediaType: content.mediaType,
                    url: content.url,
                    data: content.data,
                  } as FilePartEncoded;
                }
                default:
                  return { type: 'text', text: '' } as TextPartEncoded;
              }
            });

            return {
              role: msg.role,
              content: parts,
            } as MessageEncoded;
          }),
        };

        yield* Effect.logDebug(`[ChatPersistence.get] Reconstructed ${messages.length} messages`);
        // Return as JSON string - @effect/ai expects this format
        return Option.some(JSON.stringify(prompt));
      });

    const getMany = (
      keys: Array<string>,
    ): Effect.Effect<Array<Option.Option<unknown>>, Persistence.PersistenceError> =>
      Effect.all(keys.map(get), { concurrency: 'unbounded' });

    /**
     * Save chat history by parsing the Prompt and storing in normalized tables
     */
    const set = (
      key: string,
      value: unknown,
      _ttl: Option.Option<Duration.Duration>,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.gen(function* () {
        yield* Effect.logDebug(`[ChatPersistence.set] Saving history for ${key}`);

        // Parse the prompt - value is a JSON string from @effect/ai
        const promptJson = typeof value === 'string' ? value : JSON.stringify(value);
        const prompt = JSON.parse(promptJson) as PromptEncoded;

        yield* Effect.tryPromise({
          try: async () => {
            // Delete existing messages for this chat (full replace strategy)
            await db.delete(T.chatMessage).where(eq(T.chatMessage.chatId, key));

            // Insert new messages
            for (let msgIdx = 0; msgIdx < prompt.content.length; msgIdx++) {
              const msg = prompt.content[msgIdx];

              // Insert the message
              const [insertedMessage] = await db
                .insert(T.chatMessage)
                .values({
                  chatId: key,
                  role: msg.role,
                  sequence: msgIdx,
                })
                .returning({ id: T.chatMessage.id });

              // Insert parts
              const parts =
                typeof msg.content === 'string'
                  ? [{ type: 'text' as const, text: msg.content }]
                  : msg.content;

              for (let partIdx = 0; partIdx < parts.length; partIdx++) {
                const part = parts[partIdx];
                let partType: 'text' | 'tool-call' | 'tool-result' | 'file' | 'reasoning';
                let content: T.MessagePartContent;

                switch (part.type) {
                  case 'text':
                    partType = 'text';
                    content = { text: part.text };
                    break;
                  case 'tool-call':
                    partType = 'tool-call';
                    content = {
                      id: part.id,
                      name: part.name,
                      params: part.params,
                      providerExecuted: part.providerExecuted,
                    };
                    break;
                  case 'tool-result':
                    partType = 'tool-result';
                    content = {
                      id: part.id,
                      name: part.name,
                      result: part.result,
                      isFailure: part.isFailure,
                      providerExecuted: part.providerExecuted,
                    };
                    break;
                  case 'reasoning':
                    partType = 'reasoning';
                    content = { text: part.text };
                    break;
                  case 'file':
                    partType = 'file';
                    content = {
                      mediaType: part.mediaType,
                      url: part.url,
                      data: part.data,
                    };
                    break;
                  default:
                    continue;
                }

                await db.insert(T.chatMessagePart).values({
                  messageId: insertedMessage.id,
                  type: partType,
                  sequence: partIdx,
                  content,
                });
              }
            }
          },
          catch: (error) =>
            new Persistence.PersistenceBackingError({
              reason: 'BackingError',
              method: 'set',
              cause: error,
            }),
        });

        yield* Effect.logDebug(`[ChatPersistence.set] Saved ${prompt.content.length} messages`);
      });

    const setMany = (
      entries: ReadonlyArray<
        readonly [key: string, value: unknown, ttl: Option.Option<Duration.Duration>]
      >,
    ): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.all(
        entries.map(([key, value, ttl]) => set(key, value, ttl)),
        { concurrency: 'unbounded', discard: true },
      );

    const remove = (key: string): Effect.Effect<void, Persistence.PersistenceError> =>
      Effect.tryPromise({
        try: async () => {
          // Deleting messages will cascade to parts
          await db.delete(T.chatMessage).where(eq(T.chatMessage.chatId, key));
        },
        catch: (error) =>
          new Persistence.PersistenceBackingError({
            reason: 'BackingError',
            method: 'remove',
            cause: error,
          }),
      });

    const clear: Effect.Effect<void, Persistence.PersistenceError> = Effect.tryPromise({
      try: async () => {
        // This would delete all messages - we don't filter by storeId since normalized
        // For now, this is a no-op as we don't have a storeId concept in normalized tables
        // If needed, we could add a storeId column to chatMessage
      },
      catch: (error) =>
        new Persistence.PersistenceBackingError({
          reason: 'BackingError',
          method: 'clear',
          cause: error,
        }),
    });

    return {
      get,
      getMany,
      set,
      setMany,
      remove,
      clear,
    };
  });

// ============================================================================
// BackingPersistence Service
// ============================================================================

/**
 * BackingPersistence implementation using PostgreSQL with normalized tables.
 * This is used by @effect/ai Chat.Persisted to store conversation history.
 */
export const ChatBackingPersistenceLive = Layer.effect(
  Persistence.BackingPersistence,
  Effect.gen(function* () {
    const db = yield* Database;

    return {
      [Persistence.BackingPersistenceTypeId]: Persistence.BackingPersistenceTypeId,
      make: (storeId: string) => makeStore(storeId, db),
    } as Persistence.BackingPersistence;
  }),
);
