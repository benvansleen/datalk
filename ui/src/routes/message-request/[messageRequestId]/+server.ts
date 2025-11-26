import { getRequestEvent } from '$app/server';
import type { RequestHandler } from './$types';
import { error, redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';

import { z } from 'zod';
import { Agent, run, tool } from '@openai/agents';
import { type AgentInputItem, type Session } from '@openai/agents-core';


let tick = 0;
class PostgresMemorySession implements Session {
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


let python_server_url: string;
const getPythonServerUrl = () => {
  if (!python_server_url) {
    const { PYTHON_SERVER_HOST, PYTHON_SERVER_PORT } = process.env;
    python_server_url = `http://${PYTHON_SERVER_HOST}:${PYTHON_SERVER_PORT}`;
    console.log(`Using python_server_url: ${python_server_url}`);
  }
  return python_server_url;
};

const runPythonTool = tool({
  name: 'run_python',
  description: 'Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you',
  parameters: z.object({ python_code: z.array(z.string()) }),
  execute: async ({ python_code }) => {
    console.log(python_code);
    const url = getPythonServerUrl();

    await fetch(`${url}/environment/create`, {
      method: 'POST',
      body: JSON.stringify({
        // TODO: scope for each chat_id
        chat_id: '1',
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    const result = await fetch(`${url}/execute`, {
      method: 'POST',
      body: JSON.stringify({
        chat_id: '1',
        code: python_code,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    return await result.json();

  }

})

function requireAuth() {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
}

let model: Agent<unknown, "text">;
const getModel = () => {
  if (!model) {
    model = new Agent({
      name: 'Datalk',
      instructions: 'Use markdown elements to enhance your answer',
      tools: [runPythonTool],
      model: 'gpt-5-nano',
      modelSettings: {
        store: false,
        providerData: {
          include: ['reasoning.encrypted_content'],
        },
        // temperature: 0.4,
      },
    });
  }
  return model;
}

const sleep = (ms) => {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

export const GET: RequestHandler = async ({ params }) => {
  const user = requireAuth();
  const { messageRequestId } = params;
  console.log(`fired: ${messageRequestId}`);
  const [messageRequest] = await getDb()
    .delete(T.messageRequests)
    .where(eq(T.messageRequests.id, messageRequestId))
    .returning();
  if (!messageRequest || messageRequest.userId !== user.id) {
    error(404, 'Could not find messageRequest');
  }
  const { chatId, content } = messageRequest;
  if (!content) {
    error(400, 'No message!');
  }

  const chat = await getDb().query.chat.findFirst({
    where: and(eq(T.chat.userId, user.id), eq(T.chat.id, chatId)),
    with: {
      messages: true,
    },
  });
  if (chat === undefined) {
    console.log('no chat!');
    redirect(307, `/`);
  }

  const session = new PostgresMemorySession({
    sessionId: chatId,
  });
  const res = await run(getModel(), content, {
    session,
    stream: true,
  });

  const stream = new ReadableStream({
    async start(controller) {
      const send = (obj: object) => controller.enqueue(`data: ${JSON.stringify(obj)}\n\n`);

      try {
        for await (const event of res) {
          if (event.type == 'raw_model_stream_event' && event.data.type === 'model') {
            switch (event.data.event.type) {
              case 'response.output_text.delta':
              case 'response.function_call_arguments.delta':
              case 'response.function_call_arguments.done': {
                send(event.data.event);
                break;
              }
            }
          }
        }
        send({ type: 'response_done' });
      } catch (err) {
        console.log(err);
      }
    },
  });
  return new Response(stream, {
    headers: {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      Connection: 'keep-alive',
    },
  });
};
