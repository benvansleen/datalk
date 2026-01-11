import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import { runEffect, Auth, requestSpanFromRequest } from '$lib/server';

export const POST: RequestHandler = async ({ request, url }) => {
  await runEffect(
    Effect.gen(function* () {
      const auth = yield* Auth;
      yield* auth.logout(request.headers);
    }),
    requestSpanFromRequest(request, url, '/api/logout'),
  );

  return new Response(null, { status: 200 });
};
