import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import {
  runEffect,
  requireAuthEffect,
  subscribeChatStatus,
  streamToSSE,
} from '$lib/server/effect';

/**
 * SSE endpoint for chat status events.
 *
 * Streams chat lifecycle events (created, deleted, title changed, status changed)
 * filtered to the authenticated user.
 */
export const GET: RequestHandler = async (event) => {
  return runEffect(
    Effect.gen(function* () {
      // Authenticate the user
      const user = yield* requireAuthEffect(event);

      // Create the SSE stream for this user's chat events
      const chatStream = subscribeChatStatus(user.id);

      // Convert to SSE Response
      return yield* streamToSSE(chatStream);
    }).pipe(Effect.withSpan('GET /chat-status-events'))
  );
};
