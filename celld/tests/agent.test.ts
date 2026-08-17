import { Effect } from 'effect';
import { describe, expect, it } from 'vitest';
import type { StoredChatSnapshot } from '../src/cell/shared';
import {
  Agent,
  GenerationSink,
  toModelMessages,
  type GenerationSinkShape,
} from '../src/services/Agent';
import type { ChatMessage, Env } from '../src/types';
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
      saveTitle: () => Effect.void,
      spawn: () => Effect.void,
      saveImages: () => Effect.succeed([]),
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

  it('synthesizes results for tool calls interrupted before a result was recorded', () => {
    const messages = [
      { id: 'u1', role: 'user', content: 'count the games', createdAt: 1 },
      {
        id: 'a1',
        role: 'assistant',
        content: '',
        createdAt: 2,
        toolCalls: [
          { toolCallId: 'call-1', toolName: 'run_sql', args: '{}' },
          { toolCallId: 'call-2', toolName: 'run_python', args: '{}' },
        ],
      },
    ] as unknown as ChatMessage[];

    const modelMessages = toModelMessages(messages);

    expect(modelMessages).toEqual([
      { role: 'user', content: 'count the games' },
      {
        role: 'assistant',
        content: [
          { type: 'tool-call', toolCallId: 'call-1', toolName: 'run_sql', input: {} },
          { type: 'tool-call', toolCallId: 'call-2', toolName: 'run_python', input: {} },
        ],
      },
      {
        role: 'tool',
        content: [
          {
            type: 'tool-result',
            toolCallId: 'call-1',
            toolName: 'run_sql',
            output: {
              type: 'text',
              value: 'Tool execution was interrupted before a result was recorded.',
            },
          },
        ],
      },
      {
        role: 'tool',
        content: [
          {
            type: 'tool-result',
            toolCallId: 'call-2',
            toolName: 'run_python',
            output: {
              type: 'text',
              value: 'Tool execution was interrupted before a result was recorded.',
            },
          },
        ],
      },
    ]);
  });

  it('keeps answered tool calls and drops orphaned tool results when rebuilding the prompt', () => {
    const messages = [
      { id: 'u1', role: 'user', content: 'hello', createdAt: 1 },
      {
        id: 'a1',
        role: 'assistant',
        content: 'checking',
        createdAt: 2,
        toolCalls: [{ toolCallId: 'call-1', toolName: 'check_environment', args: '{}' }],
      },
      {
        id: 'call-1',
        role: 'tool',
        content: "[('games',)]",
        createdAt: 3,
        toolCallId: 'call-1',
        toolName: 'check_environment',
      },
      {
        id: 'call-9',
        role: 'tool',
        content: 'stale result',
        createdAt: 4,
        toolCallId: 'call-9',
        toolName: 'run_python',
      },
    ] as unknown as ChatMessage[];

    const modelMessages = toModelMessages(messages);

    expect(modelMessages).toEqual([
      { role: 'user', content: 'hello' },
      {
        role: 'assistant',
        content: [
          { type: 'text', text: 'checking' },
          { type: 'tool-call', toolCallId: 'call-1', toolName: 'check_environment', input: {} },
        ],
      },
      {
        role: 'tool',
        content: [
          {
            type: 'tool-result',
            toolCallId: 'call-1',
            toolName: 'check_environment',
            output: { type: 'text', value: "[('games',)]" },
          },
        ],
      },
    ]);
  });
});
