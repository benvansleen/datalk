import type { Actions, PageServerLoad } from './$types';
import { redirect, fail } from '@sveltejs/kit';
import { Effect, Console } from 'effect';
import { runEffect } from '$lib/server/effect';
import { publishChatStatus } from '$lib/server/effect/api/chat';
import {
  createChat as dbCreateChat,
  deleteChat as dbDeleteChat,
  getChatsForUser,
} from '$lib/server/effect/api/db';
import { listDatasets } from '$lib/server/effect/api/python';

export const load: PageServerLoad = async ({ locals }) => {
  const user = locals.user;

  const [datasets, chats] = await Promise.all([
    runEffect(listDatasets),
    runEffect(
      Effect.gen(function* () {
        return yield* getChatsForUser(user.id);
      }).pipe(Effect.withSpan('Chat.get-chats'))
    ),
  ]);

  return {
    datasets,
    chats,
  };
};

export const actions: Actions = {
  createChat: async ({ request, locals }) => {
    const user = locals.user;
    const formData = await request.formData();
    const dataset = formData.get('dataset') as string;

    if (!dataset) {
      return fail(400, { error: 'Dataset is required' });
    }

    const chatId = await runEffect(
      Effect.gen(function* () {
        const chatId = yield* dbCreateChat(user.id, dataset);
        yield* Console.log(`created: ${chatId}`);
        yield* publishChatStatus({ type: 'chat-created', userId: user.id, chatId });
        return chatId;
      }).pipe(Effect.withSpan('Chat.creation-request'))
    );

    redirect(303, `/chat/${chatId}`);
  },

  deleteChat: async ({ request, locals }) => {
    const user = locals.user;
    const formData = await request.formData();
    const chatId = formData.get('chatId') as string;

    if (!chatId) {
      return fail(400, { error: 'Chat ID is required' });
    }

    await runEffect(
      Effect.gen(function* () {
        yield* dbDeleteChat(user.id, chatId);
        yield* publishChatStatus({ type: 'chat-deleted', userId: user.id, chatId });
      }).pipe(Effect.withSpan('Chat.deletion-request'))
    );

    return { success: true };
  },
};
