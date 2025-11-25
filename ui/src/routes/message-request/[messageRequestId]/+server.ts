import { getRequestEvent } from '$app/server';
import type { RequestHandler } from './$types';
import { error, redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';
import * as llm from 'multi-llm-ts';


let python_server_url: string;
const getPythonServerUrl = () => {
  if (!python_server_url) {
    const { PYTHON_SERVER_HOST, PYTHON_SERVER_PORT } = process.env;
    python_server_url = `http://${PYTHON_SERVER_HOST}:${PYTHON_SERVER_PORT}`;
  }
  return python_server_url
}

class PythonPlugin extends llm.Plugin {
  isEnabled(): boolean {
    return true;
  }

  getName(): string {
    return "PythonInterpreter";
  }

  getDescription(): string {
    return "Provide lines of python code to be executed by a python interpreter. The results of stdout, stderr, & possible exceptions will be returned to you";
  }

  getPreparationDescription(tool: string): string {
    return 'Preparing to execute PythonPlugin';
  }

  getRunningDescription(tool: string, args: any): string {
    return args;
  }

  getParameters(): llm.PluginParameter[] {
    return [{
      name: 'python_code',
      type: 'array',
      items: {
        type: 'string',
      },
      description: "Lines of python code to be executed",
      required: true,
    }]
  }

  async execute(context: llm.PluginExecutionContext, parameters): Promise<any> {
    console.log(parameters);
    const url = getPythonServerUrl();

    await fetch(`${url}/environment/create`, {
      method: 'POST',
      body: JSON.stringify({
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
        code: parameters.python_code,
      }),
      headers: {
        'Content-Type': 'application/json',
      },
    });

    return await result.json();
  }
}

function requireAuth() {
  const {
    locals: { user },
  } = getRequestEvent();
  if (!user) {
    redirect(307, '/login');
  }
  return user;
}

let model: llm.LlmModel | undefined;
const getModel = () => {
  if (!model) {
    const config = { apiKey: process.env.OPENAI_API_KEY };
    model = llm.igniteModel('openai', 'gpt-5-nano', config);
    model.addPlugin(new PythonPlugin());
  }
  return model;
};

export const GET: RequestHandler = async ({ params }) => {
  const user = requireAuth();
  const { messageRequestId } = params;
  console.log(`fired: ${messageRequestId}`)
  const [messageRequest] = await getDb()
    .delete(T.messageRequests)
    .where(eq(T.messageRequests.id, messageRequestId))
    .returning();
  if (!messageRequest || messageRequest.userId !== user.id) {
    error(404, 'Could not find messageRequest');
  }
  const { chatId, content } = messageRequest;

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

  console.log(chat);
  const messages = chat.messages
  .filter( ({ type }) => type !== 'tool')
  .map(
    ({ type, content }) => new llm.Message(type as llm.LlmRole, content),
  );
  messages.push(new llm.Message('user', content));

  console.log(messages);
  const res = getModel().generate(messages);

  const stream = new ReadableStream({
    async start(controller) {
      const chunks = [];
      const tools = [];
      for await (const chunk of res) {
        if (chunk.type === 'content') {
          chunks.push(chunk.text);
        } else if (chunk.type === 'tool' && chunk.done) {
          tools.push(chunk.call);
        }
        controller.enqueue(`data: ${JSON.stringify(chunk)}\n\n`);
      }
      try {
        await getDb()
          .insert(T.message)
          .values([
            {
              chatId,
              content,
              type: 'user',
            },
            ...tools.map(tool => {
              return {
                chatId,
                content: JSON.stringify(tool) ?? "empty??",
                type: 'tool',
              };
            }),
            {
              chatId,
              content: chunks.join(''),
              type: 'assistant',
            },
          ]);

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
