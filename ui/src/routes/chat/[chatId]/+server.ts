import { requireAuth } from '$lib/server/auth';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';
import type { RequestHandler } from './$types';
import { flattenMessages, runChatTitleGenerator } from '$lib/server/responses/utils';
import { PostgresMemorySession } from '$lib/server/responses/session';
import { getModel } from '$lib/server/responses/model';
import { run } from '@openai/agents';
import { getRedis } from '$lib/server/redis';

const generateChatTitle = async (userId: string, chatId: string, currentMessage: string) => {
  const recentMessages = await getDb().query.ResponsesApiMessage.findMany({
    where: and(eq(T.ResponsesApiMessage.chatId, chatId), eq(T.ResponsesApiMessage.role, 'user')),
    with: { messageContents: true },
    limit: 5,
  });
  const flattenedMessages = flattenMessages(recentMessages).map(({ content }) => content);
  const conversationSnapshot = [...flattenedMessages, currentMessage];
  const title = await runChatTitleGenerator(conversationSnapshot);
  await getDb().update(T.chat).set({ title }).where(eq(T.chat.id, chatId));

  const redis = await getRedis();
  await redis.publish(
    'chat-status',
    JSON.stringify({ type: 'title-changed', userId, chatId, title }),
  );
};

const generateResponse = async (
  userId: string,
  chatId: string,
  dataset: string,
  messageId: string,
  currentMessage: string,
) => {
  const redis = await getRedis();
  await redis.publish(
    'chat-status',
    JSON.stringify({ type: 'status-changed', userId, chatId, currentMessageId: messageId }),
  );

  const session = new PostgresMemorySession({
    sessionId: chatId,
  });
  const res = await run(getModel(), currentMessage, {
    session,
    context: { chatId, dataset },
    stream: true,
  });

  for await (const event of res) {
    if (event.type == 'raw_model_stream_event' && event.data.type === 'model') {
      switch (event.data.event.type) {
        case 'response.output_text.delta':
        case 'response.function_call_arguments.delta':
        case 'response.function_call_arguments.done': {
          const chunk = JSON.stringify(event.data.event);
          await redis.lPush(`gen:${messageId}:history`, chunk);
          await redis.publish(`gen:${messageId}`, chunk);
          break;
        }

        default: {
          // console.log(JSON.stringify(event));
        }
      }
    }
  }
  await redis.publish(`gen:${messageId}`, JSON.stringify({ type: 'response_done' }));
  await redis.set(`gen:${messageId}:done`, '1');
  await redis.publish(
    'chat-status',
    JSON.stringify({ type: 'status-changed', userId, chatId, currentMessageId: null }),
  );
  await getDb().update(T.chat).set({ currentMessageRequest: null }).where(eq(T.chat.id, chatId));
};

export const POST: RequestHandler = async ({ request, params }) => {
  const user = requireAuth();
  const { chatId } = params;
  const content = await request.text();
  console.log(content);

  // fire-and-forget. Don't really care if this fails or when it happens!
  generateChatTitle(user.id, chatId, content).catch((err) =>
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

  const [{ dataset }] = await getDb()
    .update(T.chat)
    .set({ currentMessageRequest: messageRequestId })
    .where(eq(T.chat.id, chatId))
    .returning({ dataset: T.chat.dataset });

  generateResponse(user.id, chatId, dataset, messageRequestId, content).catch((err) =>
    console.log(`Error generating response for ${messageRequestId}: ${err}`),
  );
  return new Response(messageRequestId, {
    headers: {
      'Content-Type': 'text/plain',
      'Cache-Control': 'no-cache',
    },
  });
};
