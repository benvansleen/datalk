import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import { runEffect, Auth } from '$lib/server/effect';

export const POST: RequestHandler = async ({ request }) => {
  await runEffect(
    Effect.gen(function* () {
      const auth = yield* Auth;
      yield* auth.logout(request.headers);
    })
  );

  return new Response(null, { status: 200 });
};
