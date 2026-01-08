import type { RequestHandler } from './$types';
import { Effect, Option } from 'effect';
import {
  runEffect,
  getMessageRequest,
  subscribeGenerationEvents,
  streamToSSE,
  AuthError,
} from '$lib/server';
import { getRequestEvent } from '$app/server';

/**
 * SSE endpoint for message generation events.
 *
 * Streams AI response generation events for a specific message request.
 * Includes history replay for reconnecting clients.
 */
export const GET: RequestHandler = async (event) => {
  const { locals: { user } } = getRequestEvent();
  const { messageRequestId } = event.params;

  return runEffect(
    Effect.gen(function* () {
      // Get the message request and verify ownership
      const messageRequestOption = yield* getMessageRequest(messageRequestId);
      if (Option.isNone(messageRequestOption)) {
        return yield* Effect.fail(new Error('Message request not found'));
      }
      if (messageRequestOption.value.userId !== user.id) {
        return yield* Effect.fail(new AuthError({ message: `user (${user.id}) does not own message request (${messageRequestId})`}))
      }

      // Create the SSE stream for this message request's generation events
      yield* Effect.logDebug(`Subscribing to generation events for: ${messageRequestId}`);
      const generationStream = subscribeGenerationEvents(messageRequestId);

      // Convert to SSE Response
      return yield* streamToSSE(generationStream);
    }).pipe(Effect.withSpan('GET /message-request/:id'))
  );
};
