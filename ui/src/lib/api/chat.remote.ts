import * as v from 'valibot';
import { form, query } from '$app/server';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { redirect } from '@sveltejs/kit';
import { eq, and, desc } from 'drizzle-orm';
import { requireAuth } from '$lib/server/auth';
import { flattenMessages } from '$lib/server/responses/utils';
import { getRedis } from '$lib/server/redis';
import { getPythonServerUrl } from '$lib/server/responses/tools';

export const availableDatasets = query(async () => {
  const url = getPythonServerUrl();
  const res = await fetch(`${url}/dataset/list`, { method: 'GET' });
  const datasets = await res.json()
  return datasets;
})

const CreateChatS = v.object({ dataset: v.custom<string>((value) => value !== "Select a dataset") });
export const createChat = form(CreateChatS, async ({dataset}) => {
  const user = requireAuth();
  const [{ chatId }] = await getDb()
    .insert(T.chat)
    .values({
      userId: user.id,
      dataset,
      title: '...',
      currentMessageRequest: null,
    })
    .returning({ chatId: T.chat.id });

  console.log(chatId);
  const redis = await getRedis();
  await redis.publish('chat-status', JSON.stringify({ userId: user.id, type: 'chat-created' }));
  redirect(300, `/chat/${chatId}`);
});

export const getChats = query(async () => {
  const user = requireAuth();
  const chats = await getDb()
    .select()
    .from(T.chat)
    .where(eq(T.chat.userId, user.id))
    .orderBy(desc(T.chat.updatedAt));
  return chats;
});

export const getChatMessages = query(v.pipe(v.string(), v.uuid()), async (chatId) => {
  const user = requireAuth();

  const chat = await getDb().query.chat.findFirst({
    where: and(eq(T.chat.userId, user.id), eq(T.chat.id, chatId as string)),
    with: {
      messages: { with: { messageContents: true } },
      functionCalls: true,
      functionResults: true,
    },
  });
  if (chat === undefined) {
    console.log('no chat!');
    redirect(307, `/`);
  }

  const flattenedMessages = flattenMessages(chat.messages);
  const flattenedFunctions = [];
  // really ugly n^2 search here. Not really worth optimizing
  // since n is pretty reliably < 10
  for (const call of chat.functionCalls) {
    for (const result of chat.functionResults) {
      if (call.callId === result.callId) {
        flattenedFunctions.push({
          eventIdx: call.eventIdx,
          name: call.name,
          arguments: call.arguments,
          output: result.output,
        });
      }
    }
  }

  const messages = [...flattenedMessages, ...flattenedFunctions].sort((a, b) => {
    if (a.eventIdx > b.eventIdx) {
      return 1;
    }
    if (a.eventIdx < b.eventIdx) {
      return -1;
    }
    return 0;
  });

  return { currentMessageRequestId: chat.currentMessageRequest, messages };
});
