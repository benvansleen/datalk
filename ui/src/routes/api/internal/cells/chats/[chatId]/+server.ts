import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import {
  InternalCellError,
  hydrateChat,
  verifyInternalCellRequest,
} from '$lib/server/internal-cells';
import { requestSpanFromRequest, runEffect } from '$lib/server';

export const GET: RequestHandler = async ({ request, url, params }) => {
  const userId = url.searchParams.get('userId');
  if (!userId) return Response.json({ error: 'userId is required' }, { status: 400 });
  try {
    const result = await runEffect(
      Effect.gen(function* () {
        yield* verifyInternalCellRequest(request, '');
        return yield* hydrateChat(params.chatId, userId);
      }),
      requestSpanFromRequest(request, url, '/api/internal/cells/chats/[chatId]'),
    );
    return result ? Response.json(result) : Response.json({ error: 'Not found' }, { status: 404 });
  } catch (error) {
    const internalError = error instanceof InternalCellError ? error : undefined;
    return Response.json(
      { error: internalError?.message ?? 'Internal server error' },
      { status: internalError?.status ?? 500 },
    );
  }
};
