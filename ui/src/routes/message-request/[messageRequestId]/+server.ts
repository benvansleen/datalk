import { and, eq } from 'drizzle-orm';
import { run } from '@openai/agents';
import type { RequestHandler } from './$types';
import { error, redirect } from '@sveltejs/kit';
import { getDb } from '$lib/server/db';
import * as T from '$lib/server/db/schema';
import { requireAuth } from '$lib/server/auth';
import { PostgresMemorySession } from '$lib/server/responses/session';
import { getModel } from '$lib/server/responses/model';

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
