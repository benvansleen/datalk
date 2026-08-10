import { Effect } from 'effect';
import { describe, expect, it } from 'vitest';
import type { StoredChatSnapshot } from '../src/cell/shared';
import { Agent, GenerationSink, type GenerationSinkShape } from '../src/services/Agent';
import type { Env } from '../src/types';
import { runWithEnv } from './helpers/runtime';

const env = {} as Env;

describe('Agent service', () => {
  it('reports a response error when AI generation is not configured', async () => {
    const appended: Array<{ type: string; data: unknown }> = [];
    const sink: GenerationSinkShape = {
      append: (type, data) =>
        Effect.sync(() => {
          appended.push({ type, data });
        }),
      emit: () => Effect.void,
      save: () => Effect.void,
      spawn: () => Effect.void,
    };
    const snapshot = {
      id: 'chat-1',
      title: '...',
      messages: [],
      events: [],
    } as unknown as StoredChatSnapshot;

    await runWithEnv(
      env,
      Effect.gen(function* () {
        const agent = yield* Agent;
        return yield* agent.runGeneration(snapshot, 'request-1');
      }).pipe(Effect.provideService(GenerationSink, sink)),
    );

    expect(appended).toEqual([
      { type: 'response_error', data: { message: 'AI generation is not configured' } },
      { type: 'response_done', data: { messageRequestId: 'request-1' } },
    ]);
  });
});
