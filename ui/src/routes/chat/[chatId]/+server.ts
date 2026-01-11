import * as T from '$lib/server/db/schema';
import { and, eq, isNull } from 'drizzle-orm';
import type { RequestHandler } from './$types';
import { error } from '@sveltejs/kit';
import {
  AuthError,
  ChatTitleGenerator,
  Database,
  DatabaseError,
  DatalkAgent,
  type DatalkStreamPart,
  runEffectExit,
  runEffectFork,
  publishChatStatus,
  publishGenerationEvent,
  markGenerationComplete,
  requireChatOwnership,
  requestSpanFromRequest,
} from '$lib/server';
import { Effect, Stream, Option, Exit, Cause } from 'effect';

/**
 * Generate a title for the chat based on recent messages.
 * This runs in the background and doesn't block the response.
 */
const generateChatTitle = Effect.fn('generateChatTitle')(function* (
  userId: string,
  chatId: string,
  currentMessage: string,
) {
  const db = yield* Database;
  const chatTitleGenerator = yield* ChatTitleGenerator;

  // Get recent user messages from the new chat history
  // For now, just use the current message as the snapshot
  const conversationSnapshot = [currentMessage];
  const title = yield* chatTitleGenerator.run(conversationSnapshot);

  yield* db.update(T.chat).set({ title }).where(eq(T.chat.id, chatId));
  yield* publishChatStatus({ type: 'title-changed', userId, chatId, title });
});

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
    { concurrency: 'unbounded' },
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

export const POST: RequestHandler = async ({ request, params, locals, url }) => {
  const { user } = locals;
  const { chatId } = params;
  const content = await request.text();

  return Exit.match(
    await runEffectExit(
      Effect.gen(function* () {
        yield* Effect.annotateCurrentSpan({ userId: user.id, chatId, content });

        yield* requireChatOwnership(user.id, chatId);

        // Fire-and-forget title generation (errors are logged by runEffectFork)
        runEffectFork(
          generateChatTitle(user.id, chatId, content).pipe(
            Effect.withSpan('generateChatTitle', { attributes: { userId: user.id, chatId } }),
          ),
        );

        const db = yield* Database;
        const [{ messageRequestId }] = yield* db
          .insert(T.messageRequests)
          .values({
            userId: user.id,
            chatId,
            content,
          })
          .returning({ messageRequestId: T.messageRequests.id });

        const res = yield* db
          .update(T.chat)
          .set({ currentMessageRequest: messageRequestId })
          .where(
            and(
              eq(T.chat.id, chatId),
              eq(T.chat.userId, user.id),
              isNull(T.chat.currentMessageRequest),
            ),
          )
          .returning({ dataset: T.chat.dataset });

        if (res.length === 0) {
          return yield* Effect.fail(
            new DatabaseError({ message: 'Already generating a response for this chat' }),
          );
        }

        // Fire-and-forget response generation (errors are logged by runEffectFork)
        const [{ dataset }] = res;
        runEffectFork(
          generateResponse(user.id, chatId, dataset, messageRequestId, content).pipe(
            Effect.withSpan('generateResponse', {
              attributes: { userId: user.id, chatId, messageRequestId },
            }),
          ),
        );
        return new Response(messageRequestId, {
          headers: {
            'Content-Type': 'text/plain',
            'Cache-Control': 'no-cache',
          },
        });
      }).pipe(Effect.withSpan('POST /chat/[chatId]')),
      requestSpanFromRequest(request, url, '/chat/[chatId]'),
    ),
    {
      onSuccess: (response) => response,
      onFailure: (cause) => {
        if (Cause.isFailType(cause)) {
          if (cause.error instanceof AuthError) {
            return error(403, cause.error.message);
          }
          if (cause.error instanceof DatabaseError) {
            return error(400, cause.error.message);
          }
        }
        return error(500, 'An unexpected error occurred');
      },
    },
  );
};
