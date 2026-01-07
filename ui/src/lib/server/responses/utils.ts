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
