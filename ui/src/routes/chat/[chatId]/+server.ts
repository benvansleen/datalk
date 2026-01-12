import * as T from '$lib/server/db/schema';
import { and, eq, isNull } from 'drizzle-orm';
import type { RequestHandler } from './$types';
import { error } from '@sveltejs/kit';
import {
  AuthError,
  ChatTitleGenerator,
  Database,
  DatabaseError,
  generateResponse,
  runEffectExit,
  runEffectFork,
  publishChatStatus,
  requireChatOwnership,
  requestSpanFromRequest,
} from '$lib/server';
import { Effect, Exit, Cause } from 'effect';

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
