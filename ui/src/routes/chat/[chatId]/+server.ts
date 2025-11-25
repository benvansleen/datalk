import { getRequestEvent } from '$app/server';
import { redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';

function requireAuth() {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
}

export const POST = async ({ request, params }) => {
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
