import type { RequestHandler } from './$types';
import { Effect } from 'effect';
import { error } from '@sveltejs/kit';
import { LiveSession, requestSpanFromRequest, runEffect } from '$lib/server';

const isSameOrigin = (request: Request, url: URL) => request.headers.get('origin') === url.origin;

export const POST: RequestHandler = async ({ request, url, locals, cookies }) => {
  if (!isSameOrigin(request, url)) {
    error(403, 'Cross-origin live-session requests are not allowed');
  }

  const session = await runEffect(
    Effect.gen(function* () {
      const liveSession = yield* LiveSession;
      return yield* liveSession.mint(locals.user.id);
    }),
    requestSpanFromRequest(request, url, '/api/live-session'),
  );

  cookies.set('datalk_live', session.token, {
    path: '/live',
    httpOnly: true,
    sameSite: 'strict',
    secure: url.protocol === 'https:',
    expires: new Date(session.expiresAt * 1000),
  });

  return new Response(null, { status: 204, headers: { 'cache-control': 'no-store' } });
};
