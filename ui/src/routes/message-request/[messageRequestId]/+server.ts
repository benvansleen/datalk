import { getRequestEvent } from '$app/server';
import type { RequestHandler } from './$types';
import { error, redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, desc, eq } from 'drizzle-orm';
// import * as llm from 'multi-llm-ts';

import { z } from 'zod';
import { Agent, run, tool, user as mkUserMsg, assistant as mkAsstMsg } from '@openai/agents';
import { type AgentInputItem, type Session } from '@openai/agents-core';
import { ca } from 'zod/v4/locales';
import { out } from '$env/static/private';

function cloneAgentItem<T extends AgentInputItem>(item: T): T {
  return structuredClone(item);
}
class PostgresMemorySession implements Session {
  private readonly sessionId: string;
  private items: AgentInputItem[];

  constructor(
    options: {
      sessionId?: string;
      initialItems?: AgentInputItem[];
    } = {},
  ) {
    this.sessionId = options.sessionId!;
    this.items = options.initialItems
      ? options.initialItems.map(cloneAgentItem)
      : [];
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

    // console.log(items.functionResults);
    // const messages = items.Rmessages;
    // const functionResults = items.functionResults.map(({ name, callId, status, output, createdAt }) => {
    //   return {
    //     name,
    //     callId,
    //     status,
    //     output: JSON.parse(output as string),
    //     createdAt,
    //   };
    // });
    // const providerData = items.providerData.map(({ createdAt, data }) => {
    //   return {
    //     createdAt,
    //     data: ,
    //   };
    // });

    const loadedItems = [
      ...items.Rmessages.map(({ role, messageContents, createdAt }) => {
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
          createdAt,
          role,
          content,
        }
      }),
      ...items.functionCalls.map(({ createdAt, name, callId, status, arguments: args, providerData }) => ({
        createdAt,
        providerData,
        type: 'function_call',
        name,
        callId,
        status,
        arguments: args,
      })),
      ...items.functionResults.map(({ createdAt, name, callId, status, output }) => ({
        createdAt,
        type: "function_call_result",
        name,
        callId,
        status,
        output,
      })),
      ...items.providerData.map(({ createdAt, misc }) => ({
        createdAt,
        ...misc as object,
      })),
    ].sort((a, b) => {
      if (a.createdAt > b.createdAt) {
        return 1
      }
      if (a.createdAt < b.createdAt) {
        return -1
      }
      return 0;
    });

    loadedItems.forEach(item => {
      delete item.createdAt;
      delete item.chatId;
      // delete item.id;
    })

    console.log('------------ loaded items ---------------')
    console.log(JSON.stringify(loadedItems));

    return loadedItems;


    // const items = await getDb().query.ResponsesApiSession.findMany({
    //   where: eq(T.ResponsesApiSession.chatId, this.sessionId),
    //   orderBy: [desc(T.chat.createdAt)],
    //   limit,
    // });
    // console.log(
    //   `Getting items from memory session (${this.sessionId}): ${JSON.stringify(items)}`,
    // );
    //
    // const loadedItems = items.map(item => JSON.parse(item.item as string));
    // return loadedItems;

    // if (limit === undefined) {
    //   const cloned = this.items.map(cloneAgentItem);
    //   console.log(
    //     `Getting items from memory session (${this.sessionId}): ${JSON.stringify(cloned)}`,
    //   );
    //   return cloned;
    // }
    // if (limit <= 0) {
    //   return [];
    // }
    // const start = Math.max(this.items.length - limit, 0);
    // const items = this.items.slice(start).map(cloneAgentItem);
    // console.log(
    //   `Getting items from memory session (${this.sessionId}): ${JSON.stringify(items)}`,
    // );
    // return items;
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
              misc: item,
            });
          } else {
            throw new Error(`Attempting to save unknown item type: ${JSON.stringify(item)}`);
          }
        }
      }
    }));

    // await getDb()
    //   .insert(T.ResponsesApiSession)
    //   .values(items.map(item => {
    //     return {
    //       chatId: this.sessionId,
    //       type: item.type as string,
    //       item: JSON.stringify(item),
    //     };
    //   }));
    // const cloned = items.map(cloneAgentItem);
    // console.log(
    //   `Adding items to memory session (${this.sessionId}): ${JSON.stringify(cloned)}`,
    // );
    // this.items = [...this.items, ...cloned];
  }

  async popItem(): Promise<AgentInputItem | undefined> {
    throw new Error("Not implemented!")
    // const item = this.items[this.items.length - 1];
    // const cloned = cloneAgentItem(item);
    // console.log(
    //   `Popping item from memory session (${this.sessionId}): ${JSON.stringify(cloned)}`,
    // );
    // this.items = this.items.slice(0, -1);
    // return cloned;
  }

  async clearSession(): Promise<void> {
    console.log(`Clearing memory session (${this.sessionId})`);
    throw new Error("Not implemented!")
    // this.items = [];
    // await getDb().delete(T.ResponsesApiSession).where(eq(T.ResponsesApiSession.chatId, this.sessionId));
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

// class PythonPlugin extends llm.Plugin {
//   isEnabled(): boolean {
//     return true;
//   }
//
//   getName(): string {
//     return 'PythonInterpreter';
//   }
//
//   getDescription(): string {
//     return 'Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you';
//   }
//
//   getPreparationDescription(tool: string): string {
//     return 'Preparing to execute Python';
//   }
//
//   getRunningDescription(tool: string, args: any): string {
//     return 'Python running';
//   }
//
//   getCompletedDescription(tool: string, args: any, results: any): string | undefined {
//     return 'Python finished!'
//   }
//
//   getParameters(): llm.PluginParameter[] {
//     return [
//       {
//         name: 'python_code',
//         type: 'array',
//         items: {
//           type: 'string',
//         },
//         description: 'Lines of python code to be executed',
//         required: true,
//       },
//     ];
//   }
//
//   async execute(context: llm.PluginExecutionContext, parameters): Promise<any> {
//     console.log(parameters);
//     const url = getPythonServerUrl();
//
//     await fetch(`${url}/environment/create`, {
//       method: 'POST',
//       body: JSON.stringify({
//         // TODO: scope for each chat_id
//         chat_id: '1',
//       }),
//       headers: {
//         'Content-Type': 'application/json',
//       },
//     });
//
//     const result = await fetch(`${url}/execute`, {
//       method: 'POST',
//       body: JSON.stringify({
//         chat_id: '1',
//         code: parameters.python_code,
//       }),
//       headers: {
//         'Content-Type': 'application/json',
//       },
//     });
//
//     return await result.json();
//   }
// }

function requireAuth() {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
}

// let model: llm.LlmModel | undefined;
// const getModel = () => {
//   if (!model) {
//     const config = { apiKey: process.env.OPENAI_API_KEY };
//     model = llm.igniteModel('openai', 'gpt-5-nano', config);
//     model.addPlugin(new PythonPlugin());
//   }
//   return model;
// };

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

  // console.log(chat);
  // const messages = [
  //   new llm.Message('system', 'Always use markdown formatting in your response.'),
  //   ...chat.messages
  //     .filter(({ type }) => type !== 'tool')
  //     .map(({ type, content }) => new llm.Message(type as llm.LlmRole, content)),
  //   new llm.Message('user', content),
  // ];
  //
  // console.log(messages);
  // const res = getModel().generate(messages, {

  // });
  // console.log(res);

  // const messages: AgentInputItem[] = chat.messages.map(({ type, content }) => {
  //   return mkUserMsg(content)
  //   // return {
  //   //   type: 'message',
  //   //   role: type,
  //   //   content: content,
  //   //   // providerData: {},
  //   // };
  // })
  // const messages: AgentInputItem[] = [
  //   ...chat.messages.map(({ type, content }) => {
  //     switch (type) {
  //       case 'user': {
  //         return mkUserMsg(content);
  //       }
  //       case 'assistant': {
  //         return mkAsstMsg(content);
  //       }
  //       default: {
  //         throw new Error('Unknown message type');
  //       }
  //     }
  //   }),
  //   mkUserMsg(content),
  // ];

  // console.log(messages);
  const session = new PostgresMemorySession({
    sessionId: chatId,
  });
  const res = await run(getModel(), content, {
    session,
    stream: true,
  });
  // for await (const event of res) {
  //   console.log(event);
  // }

  const stream = new ReadableStream({
    async start(controller) {
      const send = (obj: object) => controller.enqueue(`data: ${JSON.stringify(obj)}\n\n`);

      // const chunks = [];
      const tools = [];
      try {
        for await (const event of res) {
          // console.log(event);
          if (event.type == 'raw_model_stream_event') {
            switch (event.data.type) {
              case 'model': {
                switch (event.data.event.type) {
                  case 'response.output_text.delta': {
                    // chunks.push(event.data.event.delta);
                    send(event.data.event);
                    break;
                  }
                  case 'response.function_call_arguments.delta': {
                    send(event.data.event);
                    break;
                  }
                  case 'response.function_call_arguments.done': {
                    send(event.data.event);
                    break;
                  }
                }
                break;
              }
            }
          } else if (event.type === 'run_item_stream_event') {


            tools.push(event.item);
          }
        }
        // send({ type: 'response_done' });
      } catch (err) {
        console.log(err);
      }
      // try {
      //   await getDb()
      //     .insert(T.message)
      //     .values([
      //       {
      //         chatId,
      //         content,
      //         type: 'user',
      //       },
      //       ...tools.map((tool) => {
      //         return {
      //           chatId,
      //           content: JSON.stringify(tool),
      //           type: 'tool',
      //         };
      //       }),
      //       {
      //         chatId,
      //         content: chunks.join(''),
      //         type: 'assistant',
      //       },
      //     ]);
      // } catch (err) {
      //   console.log(err);
      // }
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
