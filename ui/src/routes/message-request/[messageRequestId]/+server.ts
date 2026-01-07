import { requireAuth } from '$lib/server/auth';
import type { RequestHandler } from './$types';
import { getRedis } from '$lib/server/redis';
import { eq } from 'drizzle-orm';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { error } from '@sveltejs/kit';

/**
 * SSE endpoint for message generation events.
 * 
 * Note: This uses getRedis() directly instead of the Effect Redis service
 * because SSE connections are long-lived and need their own subscription lifecycle.
 * The Effect Redis service is scoped to the ManagedRuntime and better suited
 * for short-lived operations (publish, get, set).
 */
export const GET: RequestHandler = async ({ params }) => {
  const user = requireAuth();
  const { messageRequestId } = params;
  console.log(`fired: ${messageRequestId}`);

  const [messageRequest] = await getDb()
    .select()
    .from(T.messageRequests)
    .where(eq(T.messageRequests.id, messageRequestId))
    .limit(1);
  if (!messageRequest || messageRequest.userId !== user.id) {
    error(404, 'Could not find messageRequest');
  }

  const redis = await getRedis();
  const stream = new ReadableStream({
    async start(controller) {
      const send = (data: string) => {
        controller.enqueue(`data: ${data}\n\n`);
      };

      try {
        // Replay history for reconnecting clients
        const history = await redis.lRange(`gen:${messageRequestId}:history`, 0, -1);
        for (const chunk of history.reverse()) {
          send(chunk);
        }
      } catch (err) {
        console.log(err);
      }

      try {
        // Subscribe to live events
        await redis.subscribe(`gen:${messageRequestId}`, (chunk) => {
          send(chunk);
        });
      } catch (err) {
        console.log(err);
      }
    },
    async cancel() {
      // Cleanup subscription when client disconnects
      try {
        await redis.unsubscribe(`gen:${messageRequestId}`);
      } catch {}
      await redis.quit();
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
