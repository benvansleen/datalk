import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import { runEffect, subscribeChatStatus, streamToSSE } from '$lib/server';
import { getRequestEvent } from '$app/server';

/**
 * SSE endpoint for chat status events.
 *
 * Streams chat lifecycle events (created, deleted, title changed, status changed)
 * filtered to the authenticated user.
 */
export const GET: RequestHandler = async () => {
  const {
    locals: { user },
  } = getRequestEvent();
  return runEffect(
    Effect.gen(function* () {
      // Create the SSE stream for this user's chat events
      const chatStream = subscribeChatStatus(user.id);

      // Convert to SSE Response
      return yield* streamToSSE(chatStream);
    }).pipe(Effect.withSpan('GET /chat-status-events')),
  );
};
