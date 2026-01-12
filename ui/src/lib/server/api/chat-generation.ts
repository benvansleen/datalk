import * as T from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';
import { Effect, Option, Stream, Cause } from 'effect';
import type { DatalkStreamPart } from '$lib/server/services/DatalkAgent';
import { DatalkAgent } from '$lib/server/services/DatalkAgent';
import { Database } from '$lib/server/services/Database';
import {
  markGenerationComplete,
  publishChatStatus,
  publishGenerationEvent,
} from '$lib/server/api/chat';

/**
 * Convert an @effect/ai stream part to a GenerationEvent for the frontend.
 * This maps the new Effect AI event format to the format expected by the frontend.
 * Returns null for events that should be filtered out.
 */
const streamPartToEvent = (part: DatalkStreamPart): Option.Option<object> => {
  switch (part.type) {
    case 'text-start':
      return Option.some({ type: 'text-start', id: part.id });

    case 'text-delta':
      return Option.some({ type: 'text-delta', id: part.id, delta: part.delta });

    case 'text-end':
      return Option.some({ type: 'text-end', id: part.id });

    case 'tool-params-start':
      return Option.some({ type: 'tool-params-start', id: part.id, name: part.name });

    case 'tool-params-delta':
      return Option.some({ type: 'tool-params-delta', id: part.id, delta: part.delta });

    case 'tool-params-end':
      return Option.some({ type: 'tool-params-end', id: part.id });

    case 'tool-call':
      return Option.some({
        type: 'tool-call',
        id: part.id,
        name: part.name,
        params: part.params,
      });

    case 'tool-result':
      return Option.some({
        type: 'tool-result',
        id: part.id,
        name: part.name,
        result: 'result' in part ? part.result : null,
        isFailure: 'isFailure' in part ? part.isFailure : false,
      });

    case 'finish':
      // Don't forward 'finish' events - these occur after each model iteration
      // The true end is signaled by 'response_done' from markGenerationComplete
      return Option.none();

    default:
      // For other events (reasoning, file, etc.), pass them through
      return Option.some(part);
  }
};

/**
 * Finalize a generation request (success or failure).
 */
export const finalizeGeneration = Effect.fn('finalizeGeneration')(function* (
  userId: string,
  chatId: string,
  messageId: string,
  errorMessage?: string,
) {
  const db = yield* Database;

  if (errorMessage) {
    yield* publishGenerationEvent(messageId, { type: 'response_error', message: errorMessage });
  }

  yield* Effect.all(
    [
      markGenerationComplete(messageId),
      publishChatStatus({ type: 'status-changed', userId, chatId, currentMessageId: null }),
      db.update(T.chat).set({ currentMessageRequest: null }).where(eq(T.chat.id, chatId)),
    ],
    { concurrency: 'inherit' },
  );
});

/**
 * Generate a response using the DatalkAgent and stream events to Redis.
 */
export const generateResponse = Effect.fn('generateResponse')(function* (
  userId: string,
  chatId: string,
  dataset: string,
  messageId: string,
  currentMessage: string,
) {
  // Publish status change - now generating
  yield* publishChatStatus({ type: 'status-changed', userId, chatId, currentMessageId: messageId });

  const agent = yield* DatalkAgent;

  // Get the stream from the agent
  const stream = yield* agent.run(chatId, dataset, currentMessage);

  // Process each stream part and publish to Redis
  const runStream = Stream.runForEach(stream, (part) => {
    const event = streamPartToEvent(part);
    return Option.match(event, {
      onSome: (event) => publishGenerationEvent(messageId, event),
      onNone: () => Effect.void,
    });
  }).pipe(
    Effect.catchAllCause((cause) =>
      finalizeGeneration(userId, chatId, messageId, Cause.pretty(cause)).pipe(
        Effect.andThen(Effect.failCause(cause)),
      ),
    ),
  );

  yield* runStream;
  yield* finalizeGeneration(userId, chatId, messageId);
});
