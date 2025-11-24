import * as v from 'valibot';
import { form, query, getRequestEvent } from '$app/server';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { redirect } from '@sveltejs/kit';
import { eq, and, desc } from 'drizzle-orm';

function requireAuth() {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
}

export const createChat = form(async () => {
  const user = requireAuth();
  const [{ chat_id }] = await getDb()
    .insert(T.chat)
    .values({
      userId: user.id,
      title: 'test title',
    })
    .returning({ chat_id: T.chat.id });

  console.log(chat_id);
  redirect(300, `/chat/${chat_id}`);
});

export const getChats = query(async () => {
  const user = requireAuth();
  const chats = await getDb().query.chat.findMany({
    where: eq(T.chat.userId, user.id),
    orderBy: [desc(T.chat.createdAt)],
  });
  return chats;
});

export const getChatMessages = query(v.pipe(v.string(), v.uuid()), async (chatId) => {
  const user = requireAuth();

  const chat = await getDb().query.chat.findFirst({
    where: and(eq(T.chat.userId, user.id), eq(T.chat.id, chatId as string)),
    with: {
      messages: true,
    },
  });
  if (chat === undefined) {
    console.log('no chat!');
    redirect(307, `/`);
  }
  return chat;
});

export const createMessage = form(
  v.object({
    chatId: v.pipe(v.string(), v.nonEmpty()),
    content: v.pipe(v.string(), v.nonEmpty()),
  }),
  async ({ chatId, content }) => {
    const _ = requireAuth();

    try {
      await getDb()
        .insert(T.message)
        .values({
          chatId: chatId as string,
          content,
          type: 'user',
        });
    } catch (err) {
      console.log(err);
      return { error: 'failed to create message' };
    }
  },
);
