import { Effect } from 'effect';
import { LanguageModel } from '@effect/ai';
import { OpenAiLanguageModel } from '@effect/ai-openai';

/**
 * Service for generating chat titles from conversation snapshots.
 * Uses OpenAI's language model to generate concise titles.
 */
export class ChatTitleGenerator extends Effect.Service<ChatTitleGenerator>()(
  'app/ChatTitleGenerator',
  {
    effect: Effect.gen(function* () {
      const model = yield* LanguageModel.LanguageModel;

      const run = Effect.fn('ChatTitleGenerator.run')(function* (conversationSnapshot: string[]) {
        const response = yield* model.generateText({
          prompt: [
            {
              role: 'system',
              content: `
# Instructions
- My job is to **simply describe** what the user is asking for based on a snapshot of their most recent messages
- I will come up with a short summary title that accurately describes the last couple messages
- I know that the title must be less than 10 words
- **I will not attempt to answer their questions** 
- I am simply providing a high-level summary of what they're asking for
                `,
            },
            {
              role: 'user',
              content: conversationSnapshot.map((msg, idx) => `${idx + 1}. ${msg}`).join('\n\n'),
            },
          ],
        });
        return response.text.trim();
      });

      return { run } as const;
    }),
    dependencies: [OpenAiLanguageModel.model('gpt-5-nano')],
  },
) {}

export const ChatTitleGeneratorLive = ChatTitleGenerator.Default;
