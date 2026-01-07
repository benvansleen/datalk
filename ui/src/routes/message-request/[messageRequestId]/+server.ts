import type { RequestHandler } from './$types';
import { Effect, Option } from 'effect';
import {
  runEffect,
  requireAuthEffect,
  requireOwnership,
  getMessageRequest,
  subscribeGenerationEvents,
  streamToSSE,
} from '$lib/server/effect';

/**
 * SSE endpoint for message generation events.
 *
 * Streams AI response generation events for a specific message request.
 * Includes history replay for reconnecting clients.
 */
export const GET: RequestHandler = async (event) => {
  const { messageRequestId } = event.params;

  return runEffect(
    Effect.gen(function* () {
      // Authenticate the user
      const user = yield* requireAuthEffect(event);

      // Get the message request and verify ownership
      const messageRequestOption = yield* getMessageRequest(messageRequestId);
      if (Option.isNone(messageRequestOption)) {
        return yield* Effect.fail(new Error('Message request not found'));
      }
      yield* requireOwnership(user, messageRequestOption.value, 'message request');

      yield* Effect.logDebug(`Subscribing to generation events for: ${messageRequestId}`);

      // Create the SSE stream for this message request's generation events
      const generationStream = subscribeGenerationEvents(messageRequestId);

      // Convert to SSE Response
      return yield* streamToSSE(generationStream);
    }).pipe(Effect.withSpan('GET /message-request/:id'))
  );
};
