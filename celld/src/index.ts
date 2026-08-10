import { Effect } from 'effect';
import { ChatCell } from './cell/chat-cell';
import { UserCell } from './cell/user-cell';
import { runEffect } from './runtime';
import { Auth } from './services/Auth';
import { Router } from './services/Router';
import type { Env } from './types';

export { ChatCell, UserCell };

const hasLiveOrigin = (request: Request, env: Env) =>
  request.headers.get('origin') === env.LIVE_ORIGIN;

export default {
  fetch(request, env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/live/health') {
      return Promise.resolve(Response.json({ ok: true }));
    }
    if (!url.pathname.startsWith('/live/')) {
      return Promise.resolve(Response.json({ error: 'Not found' }, { status: 404 }));
    }
    if (!hasLiveOrigin(request, env)) {
      return Promise.resolve(
        Response.json({ error: 'Cross-origin live requests are not allowed' }, { status: 403 }),
      );
    }

    return runEffect(
      env,
      Effect.gen(function* () {
        const auth = yield* Auth;
        const session = yield* auth.authenticate(request);
        const router = yield* Router;
        return yield* router.route(request, url, env, session.sub);
      }).pipe(
        Effect.catchAll((error) =>
          Effect.succeed(Response.json({ error: error.message }, { status: error.status })),
        ),
      ),
    );
  },
} satisfies ExportedHandler<Env>;
