import { requireAuth } from '$lib/server/auth';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';
import type { RequestHandler } from './$types';
import { flattenMessages, runChatTitleGenerator } from '$lib/server/responses/utils';

const generateChatTitle = async (chatId: string, currentMessage: string) => {
  const recentMessages = await getDb().query.ResponsesApiMessage.findMany({
    where: and(eq(T.ResponsesApiMessage.chatId, chatId), eq(T.ResponsesApiMessage.role, 'user')),
    with: { messageContents: true },
    limit: 3,
  });
  const flattenedMessages = flattenMessages(recentMessages).map(({ content }) => content);
  const conversationSnapshot = [...flattenedMessages, currentMessage];
  await getDb()
    .update(T.chat)
    .set({ title: await runChatTitleGenerator(conversationSnapshot) })
    .where(eq(T.chat.id, chatId));
};

export const POST: RequestHandler = async ({ request, params }) => {
  const user = requireAuth();
  const { chatId } = params;
  const content = await request.text();
  console.log(content);

  // fire-and-forget. Don't really care if this fails or when it happens!
  generateChatTitle(chatId, content).catch((err) =>
    console.log(`Error setting chat title for ${chatId}: ${err}`),
  );

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
