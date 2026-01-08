import type { PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { Effect, Option } from 'effect';
import { runEffect, getChatsForUser, getChatWithHistory } from '$lib/server';

export const load: PageServerLoad = async ({ locals, params }) => {
  const user = locals.user;
  const { chatId } = params;

  const [chats, chatData] = await runEffect(
    Effect.all(
      [
        getChatsForUser(user.id),
        Effect.gen(function* () {
          const result = yield* getChatWithHistory(user.id, chatId);
          if (Option.isNone(result)) {
            return null;
          }

          return {
            currentMessageRequestId: result.value.currentMessageRequest,
            messages: result.value.messages,
          } as const;
        }).pipe(Effect.withSpan('Chat.get-chat-history')),
      ],
      { concurrency: 'unbounded' },
    ),
  );

  if (!chatData) {
    redirect(303, '/');
  }

  return {
    chatId,
    chats,
    ...chatData,
  };
};
