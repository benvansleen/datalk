import { requireAuth } from '$lib/server/auth';
import { getRedis } from '$lib/server/redis';
import type { RequestHandler } from './$types';

/**
 * SSE endpoint for chat status events.
 * 
 * Note: This uses getRedis() directly instead of the Effect Redis service
 * because SSE connections are long-lived and need their own subscription lifecycle.
 * The Effect Redis service is scoped to the ManagedRuntime and better suited
 * for short-lived operations (publish, get, set).
 */
export const GET: RequestHandler = async () => {
  const user = requireAuth();

  const redis = await getRedis();
  const stream = new ReadableStream({
    async start(controller) {
      await redis.subscribe('chat-status', (message) => {
        const parsedMessage = JSON.parse(message);
        if (parsedMessage.userId === user.id) {
          controller.enqueue(`data: ${JSON.stringify(parsedMessage)}\n\n`);
        }
      });
    },
    cancel() {
      redis.unsubscribe('chat-status');
      redis.quit();
    },
  });

  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
};
