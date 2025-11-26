import { requireAuth } from '$lib/server/auth';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import type { RequestHandler } from './$types';

export const POST: RequestHandler = async ({ request, params }) => {
  const user = requireAuth();
  const { chatId } = params;
  const content = await request.text();
  console.log(content);
  const [{ messageRequestId }] = await getDb()
    .insert(T.messageRequests)
    .values({
      userId: user.id,
      chatId,
      content,
    })
    .returning({ messageRequestId: T.messageRequests.id });

  return new Response(messageRequestId, {
    headers: {
      'Content-Type': 'text/plain',
      'Cache-Control': 'no-cache',
    },
  });
};
