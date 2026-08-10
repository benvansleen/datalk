import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import {
  InternalCellError,
  hydrateUser,
  verifyInternalCellRequest,
} from '$lib/server/internal-cells';
import { requestSpanFromRequest, runEffect } from '$lib/server';

export const GET: RequestHandler = async ({ request, url, params }) => {
  try {
    const result = await runEffect(
      Effect.gen(function* () {
        yield* verifyInternalCellRequest(request, '');
        return yield* hydrateUser(params.userId);
      }),
      requestSpanFromRequest(request, url, '/api/internal/cells/users/[userId]'),
    );
    return Response.json(result);
  } catch (error) {
    const internalError = error instanceof InternalCellError ? error : undefined;
    return Response.json(
      { error: internalError?.message ?? 'Internal server error' },
      { status: internalError?.status ?? 500 },
    );
  }
};
