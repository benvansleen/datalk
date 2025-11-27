import { requireAuth } from '$lib/server/auth';
import type { RequestHandler } from './$types';
import { getRedis } from '$lib/server/redis';
import { eq } from 'drizzle-orm';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { error } from '@sveltejs/kit';

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
        console.log(data);
        controller.enqueue(`data: ${data}\n\n`);
      };

      try {
        const history = await redis.lRange(`gen:${messageRequestId}:history`, 0, -1);
        for (const chunk of history.reverse()) {
          send(chunk);
        }
      } catch (err) {
        console.log(err);
      }

      try {
        await redis.subscribe(`gen:${messageRequestId}`, (chunk) => {
          send(chunk);
        });
      } catch (err) {
        console.log(err);
      }
    },
    async cancel() {
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
