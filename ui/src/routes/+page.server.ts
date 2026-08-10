import type { PageServerLoad } from './$types';
import { Effect } from 'effect';
import { Config, getChatsForUser, requestSpanFromRequest, runEffect } from '$lib/server';

export const load: PageServerLoad = async ({ locals, request, url }) => {
  const user = locals.user;

  const [datasets, chats] = await runEffect(
    Effect.all(
      [
        Effect.gen(function* () {
          const config = yield* Config;
          return yield* Effect.tryPromise(async () => {
            const response = await fetch(`${config.pythonServerUrl}/dataset/list`);
            if (!response.ok) throw new Error(`Failed to list datasets: ${response.status}`);
            return response.json() as Promise<string[]>;
          });
        }),
        getChatsForUser(user.id),
      ],
      { concurrency: 'inherit' },
    ),
    requestSpanFromRequest(request, url, '/'),
  );

  return { datasets, chats };
};
