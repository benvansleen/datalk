import { Agent, run } from '@openai/agents';

export const flattenMessages = (
  messages: {
    role: string;
    eventIdx: number;
    id: number;
    chatId: string;
    messageContents: { content: string; id: number; messageId: number }[];
  }[],
) => {
  const flattenedMessages = [];
  for (const { role, messageContents, eventIdx } of messages) {
    for (const { content } of messageContents) {
      flattenedMessages.push({ eventIdx, role, content });
    }
  }

  return flattenedMessages;
};

let chatTitleModel: Agent<unknown, 'text'>;
const getChatTitleModel = () => {
  if (!chatTitleModel) {
    chatTitleModel = new Agent({
      name: 'ChatTitleGenerator',
      instructions: `
      # Instructions
      - My job is to **simply describe** what the user is asking for based on a snapshot of their most recent messages
      - I will come up with a short summary title that accurately describes the last couple messages
      - I know that the title must be less than 10 words
      - **I will not attempt to answer their questions** 
      - I am simply providing a high-level summary of what they're asking for
      `,
      model: 'gpt-5-nano',
      modelSettings: {
        store: false,
        providerData: {
          include: ['reasoning.encrypted_content'],
        },
      },
    });
  }
  return chatTitleModel;
};

export const runChatTitleGenerator = async (conversationSnapshot: string[]) => {
  console.log(conversationSnapshot);
  const res = await run(
    getChatTitleModel(),
    conversationSnapshot.map((msg, idx) => `${idx + 1}. ${msg}`).join('\n\n'),
    {},
  );
  const chatTitle = res.finalOutput;
  console.log(chatTitle);
  return chatTitle;
};
