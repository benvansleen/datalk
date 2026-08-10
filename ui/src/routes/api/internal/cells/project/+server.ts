import type { RequestHandler } from './$types';
import { Effect, Schema } from 'effect';
import {
  InternalCellError,
  ProjectionRequest,
  projectCellEvents,
  verifyInternalCellRequest,
} from '$lib/server/internal-cells';
import { requestSpanFromRequest, runEffect } from '$lib/server';

export const POST: RequestHandler = async ({ request, url }) => {
  const body = await request.text();
  try {
    const result = await runEffect(
      Effect.gen(function* () {
        yield* verifyInternalCellRequest(request, body);
        const payload = yield* Schema.decodeUnknown(ProjectionRequest)(JSON.parse(body)).pipe(
          Effect.mapError(
            () => new InternalCellError({ status: 400, message: 'Invalid projection payload' }),
          ),
        );
        return yield* projectCellEvents(payload);
      }),
      requestSpanFromRequest(request, url, '/api/internal/cells/project'),
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
