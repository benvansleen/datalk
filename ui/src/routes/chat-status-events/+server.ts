import { requireAuth } from '$lib/server/auth';
import { getRedis } from '$lib/server/redis';
import type { RequestHandler } from './$types';

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
