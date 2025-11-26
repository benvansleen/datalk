import { type AgentInputItem, type Session } from '@openai/agents-core';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { eq } from 'drizzle-orm';

let tick = 0;
export class PostgresMemorySession implements Session {
  private readonly sessionId: string;

  constructor(
    options: {
      sessionId?: string;
      initialItems?: AgentInputItem[];
    } = {},
  ) {
    this.sessionId = options.sessionId!;
  }

  async getSessionId(): Promise<string> {
    return this.sessionId;
  }

  async getItems(limit?: number): Promise<AgentInputItem[]> {
    const items = await getDb().query.chat.findFirst({
      where: eq(T.chat.id, this.sessionId),
      with: {
        Rmessages: { with: { messageContents: true } },
        functionCalls: true,
        functionResults: true,
        providerData: true,
      },
    });
    if (!items) {
      throw new Error("Couldn't find items associated with sessionId");
    }

    console.log(
      `Getting items from memory session (${this.sessionId}): ${JSON.stringify(items)}`,
    );

    const loadedItems = [
      ...items.Rmessages.map(({ role, messageContents, eventIdx }) => {
        let content;
        if (role === 'user') {
          content = messageContents[0].content;
        } else {
          content = messageContents.map(contents => ({
            type: 'output_text',
            text: contents.content,
          }))
        }
        console.log('------------------')
        console.log(JSON.stringify(content))
        console.log('------------------')
        return {
          eventIdx,
          role,
          content,
        }
      }),
      ...items.functionCalls.map(({ eventIdx, name, callId, status, arguments: args, providerData }) => ({
        eventIdx,
        providerData,
        type: 'function_call',
        name,
        callId,
        status,
        arguments: args,
      })),
      ...items.functionResults.map(({ eventIdx, name, callId, status, output }) => ({
        eventIdx,
        type: "function_call_result",
        name,
        callId,
        status,
        output,
      })),
      ...items.providerData.map(({ eventIdx, misc }) => ({
        eventIdx,
        ...misc as object,
      })),
    ].sort((a, b) => {
      if (a.eventIdx > b.eventIdx) {
        return 1
      }
      if (a.eventIdx < b.eventIdx) {
        return -1
      }
      return 0;
    });

    loadedItems.forEach(item => {
      delete item.eventIdx;
      delete item.chatId;
    })

    console.log('------------ loaded items ---------------')
    console.log(JSON.stringify(loadedItems));

    return loadedItems;
  }

  async addItems(items: AgentInputItem[]): Promise<void> {
    if (items.length === 0) {
      return;
    }
    console.log(
      `Adding items to memory session (${this.sessionId}): ${JSON.stringify(items)}`,
    );
    await Promise.all(items.map(async item => {
      switch (item.type) {
        case 'message': {
          const [{ messageId }] = await getDb().insert(T.ResponsesApiMessage).values({
            chatId: this.sessionId,
            eventIdx: tick++,
            role: item.role,
            content: item.content,
          }).returning({ messageId: T.ResponsesApiMessage.id });

          if (item.role === 'user') {
            return getDb().insert(T.ResponsesApiMessageContent).values({
              messageId,
              content: item.content,
            })
          } else {
            return getDb().insert(T.ResponsesApiMessageContent).values(item.content.map(({ type, text }) => {
              if (type !== 'output_text') {
                throw new Error(`Attempting to save unknown message type: ${JSON.stringify(item)}`);
              }
              return { messageId, content: text };
            }))
          }
        }

        case 'function_call': {
          return getDb().insert(T.ResponsesApiFunctionCall).values({
            chatId: this.sessionId,
            eventIdx: tick++,
            callId: item.callId,
            name: item.name,
            status: item.status,
            arguments: item.arguments,
            providerData: item.providerData,
          });
        }

        case 'function_call_result': {
          return getDb().insert(T.ResponsesApiFunctionResult).values({
            chatId: this.sessionId,
            eventIdx: tick++,
            name: item.name,
            callId: item.callId,
            status: item.status,
            output: JSON.stringify(item.output),
          });
        }

        default: {
          if (item.providerData) {
            return getDb().insert(T.ResponsesApiProviderData).values({
              chatId: this.sessionId,
              eventIdx: tick++,
              misc: item,
            });
          } else {
            throw new Error(`Attempting to save unknown item type: ${JSON.stringify(item)}`);
          }
        }
      }
    }));
  }

  async popItem(): Promise<AgentInputItem | undefined> {
    throw new Error("Not implemented!")
  }

  async clearSession(): Promise<void> {
    console.log(`Clearing memory session (${this.sessionId})`);
    throw new Error("Not implemented!")
  }
}
