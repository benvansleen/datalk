import { requireAuth } from '$lib/server/auth';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq, isNull } from 'drizzle-orm';
import type { RequestHandler } from './$types';
import { error } from '@sveltejs/kit';
import { Database, runEffect, runEffectFork } from '$lib/server/effect';
import {
  publishChatStatus,
  publishGenerationEvent,
  markGenerationComplete,
} from '$lib/server/effect/api/chat';
import { Effect, Stream } from 'effect';
import { ChatTitleGenerator } from '$lib/server/effect/services/ChatTitleGenerator';
import { DatalkAgent, type DatalkStreamPart } from '$lib/server/effect/services/DatalkAgent';

/**
 * Generate a title for the chat based on recent messages.
 * This runs in the background and doesn't block the response.
 */
const generateChatTitle = Effect.fn('generateChatTitle')(function*(userId: string, chatId: string, currentMessage:string) {
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
 */
const streamPartToEvent = (part: DatalkStreamPart): object => {
  switch (part.type) {
    case 'text-start':
      return { type: 'text-start', id: part.id };

    case 'text-delta':
      return { type: 'text-delta', id: part.id, delta: part.delta };

    case 'text-end':
      return { type: 'text-end', id: part.id };

    case 'tool-params-start':
      return { type: 'tool-params-start', id: part.id, name: part.name };

    case 'tool-params-delta':
      return { type: 'tool-params-delta', id: part.id, delta: part.delta };

    case 'tool-params-end':
      return { type: 'tool-params-end', id: part.id };

    case 'tool-call':
      return {
        type: 'tool-call',
        id: part.id,
        name: part.name,
        params: part.params,
      };

    case 'tool-result':
      return {
        type: 'tool-result',
        id: part.id,
        name: part.name,
        result: 'result' in part ? part.result : null,
        isFailure: 'isFailure' in part ? part.isFailure : false,
      };

    case 'finish':
      return { type: 'finish', reason: part.reason };

    default:
      // For other events (reasoning, file, etc.), pass them through
      return part;
  }
};

/**
 * Generate a response using the DatalkAgent and stream events to Redis.
 */
const generateResponse = Effect.fn('generateResponse')(function* (userId: string, chatId: string, dataset: string, messageId: string, currentMessage: string) {
    // Publish status change - now generating
    yield* publishChatStatus({ type: 'status-changed', userId, chatId, currentMessageId: messageId });

    const agent = yield* DatalkAgent;

    // Get the stream from the agent
    const stream = yield* agent.run(chatId, dataset, currentMessage);

    // Process each stream part and publish to Redis
    yield* Stream.runForEach(stream, (part) => {
        const event = streamPartToEvent(part);
        return publishGenerationEvent(messageId, event);
      });

    yield* Effect.all([
      markGenerationComplete(messageId),
    publishChatStatus({ type: 'status-changed', userId, chatId, currentMessageId: null }),
  ]);

    // Update chat to clear current message request
    const db = yield* Database;
    yield* db.update(T.chat).set({ currentMessageRequest: null }).where(eq(T.chat.id, chatId));
  });

export const POST: RequestHandler = async ({ request, params }) => {
  const user = requireAuth();
  const { chatId } = params;
  const content = await request.text();
  console.log(content);

  // Fire-and-forget title generation
  runEffectFork(generateChatTitle(user.id, chatId, content));

  // TODO: migrate to effect
  const [{ messageRequestId }] = await getDb()
    .insert(T.messageRequests)
    .values({
      userId: user.id,
      chatId,
      content,
    })
    .returning({ messageRequestId: T.messageRequests.id });

  const res = await getDb()
    .update(T.chat)
    .set({ currentMessageRequest: messageRequestId })
    .where(and(eq(T.chat.id, chatId), isNull(T.chat.currentMessageRequest)))
    .returning({ dataset: T.chat.dataset });

  if (res.length === 0) {
    error(400, 'Already generating a response for this chat.');
  }

  const [{ dataset }] = res;
  if (!dataset) {
    error(400, 'Chat has no dataset configured.');
  }

  // Fire-and-forget response generation
  runEffectFork(generateResponse(user.id, chatId, dataset, messageRequestId, content));

  return new Response(messageRequestId, {
    headers: {
      'Content-Type': 'text/plain',
      'Cache-Control': 'no-cache',
    },
  });
};
