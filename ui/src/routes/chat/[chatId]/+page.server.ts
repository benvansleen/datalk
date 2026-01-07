import type { PageServerLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { Effect, Option } from 'effect';
import { runEffect } from '$lib/server/effect';
import { flattenMessages } from '$lib/server/responses/utils';
import { getChatsForUser, getChatWithMessages } from '$lib/server/effect/api/db';

export const load: PageServerLoad = async ({ locals, params }) => {
  const user = locals.user;
  const { chatId } = params;

  const [chats, chatData] = await Promise.all([
    runEffect(
      Effect.gen(function* () {
        return yield* getChatsForUser(user.id);
      }).pipe(Effect.withSpan('Chat.get-chats'))
    ),
    runEffect(
      Effect.gen(function* () {
        const chat = yield* getChatWithMessages(user.id, chatId);
        if (Option.isNone(chat)) {
          return null;
        }

        const flattenedMessages = flattenMessages(chat.value.messages);
        const flattenedFunctions: {
          eventIdx: number;
          name: string;
          arguments: string;
          output: unknown;
        }[] = [];

        // really ugly n^2 search here. Not really worth optimizing
        // since n is pretty reliably < 10
        for (const call of chat.value.functionCalls) {
          for (const result of chat.value.functionResults) {
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

        return {
          currentMessageRequestId: chat.value.currentMessageRequest,
          messages,
        };
      }).pipe(Effect.withSpan('Chat.get-chat-messages'))
    ),
  ]);

  if (!chatData) {
    redirect(303, '/');
  }

  return {
    chatId,
    chats,
    ...chatData,
  };
};
