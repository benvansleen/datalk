import type { RequestHandler } from './$types';
import { Effect, Option, Schema } from 'effect';
import { InternalCellError, verifyInternalCellRequest } from '$lib/server/internal-cells';
import { Auth, requestSpanFromRequest, runEffect } from '$lib/server';

const VerifySessionRequest = Schema.Struct({
  cookie: Schema.String,
});

export const POST: RequestHandler = async ({ request, url }) => {
  const body = await request.text();
  try {
    const result = await runEffect(
      Effect.gen(function* () {
        yield* verifyInternalCellRequest(request, body);
        const payload = yield* Schema.decodeUnknown(VerifySessionRequest)(JSON.parse(body)).pipe(
          Effect.mapError(
            () => new InternalCellError({ status: 400, message: 'Invalid verify-session payload' }),
          ),
        );
        const auth = yield* Auth;
        const session = yield* auth.verifySessionCookie(payload.cookie);
        if (Option.isNone(session)) {
          return yield* Effect.fail(
            new InternalCellError({ status: 401, message: 'Invalid session' }),
          );
        }
        return session.value;
      }),
      requestSpanFromRequest(request, url, '/api/internal/auth/verify-session'),
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
