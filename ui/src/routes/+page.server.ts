import type { Actions, PageServerLoad } from './$types';
import { redirect, fail } from '@sveltejs/kit';
import { Effect, Console } from 'effect';
import { runEffect, publishChatStatus, createChat as dbCreateChat, deleteChat as dbDeleteChat, getChatsForUser, PythonServer } from '$lib/server';

export const load: PageServerLoad = async ({ locals }) => {
  const user = locals.user;

  const [datasets, chats] = await runEffect(Effect.all([
    Effect.gen(function*() {
      const pythonServer = yield* PythonServer;
      return yield* pythonServer.listDatasets;
    }),
    getChatsForUser(user.id),
  ]));

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
        yield* Effect.all([
          publishChatStatus({ type: 'chat-created', userId: user.id, chatId }),
          Console.log(`created: ${chatId}`),
        ], { concurrency: 'unbounded' });
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
      Effect.all([
        dbDeleteChat(user.id, chatId),
        publishChatStatus({ type: 'chat-deleted', userId: user.id, chatId}),
      ], { concurrency: 'unbounded' }).pipe(
          Effect.withSpan('Chat.deletion-request'),
    ));

    return { success: true };
  },
};
