import { getRequestEvent } from '$app/server';
import type { RequestHandler } from './$types';
import { redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { and, eq } from 'drizzle-orm';
import * as llm from 'multi-llm-ts';

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
  }
  return model;
};

export const POST: RequestHandler = async ({ request, params }) => {
  const user = requireAuth();
  const { chatId } = params;
  const content = await request.text();
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

  const messages = chat.messages.map(
    ({ type, content }) => new llm.Message(type as llm.LlmRole, content),
  );
  messages.push(new llm.Message('user', content));
  const res = getModel().generate(messages);

  const stream = new ReadableStream({
    async start(controller) {
      const chunks = [];
      for await (const chunk of res) {
        if (chunk.type === 'content') {
          chunks.push(chunk.text);
        }
        controller.enqueue(`data: ${JSON.stringify(chunk)}\n\n`);
      }
      await getDb()
        .insert(T.message)
        .values([
          {
            chatId,
            content,
            type: 'user',
          },
          {
            chatId,
            content: chunks.join(''),
            type: 'assistant',
          },
        ]);
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
