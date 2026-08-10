import { createOpenAI } from '@ai-sdk/openai';
import { Context, Effect, Either, JSONSchema, Match, Option, Schema, Stream } from 'effect';
import { generateText, isStepCount, jsonSchema, streamText, tool, type ModelMessage } from 'ai';
import { ChatMessage, HttpError } from '../types';
import type { StoredChatSnapshot } from '../cell/shared';
import { Config, ConfigLive } from './Config';
import { PythonServer, PythonServerLive } from './PythonServer';

const MAX_AGENT_ITERATIONS = 10;

const systemPrompt = `
# Instructions
- Use run_python or run_sql whenever computation would improve the answer.
- Format answers in Markdown.
- The user is probably referring to the selected dataset.
`.trim();

const aiSchema = <A, I>(schema: Schema.Schema<A, I, never>) =>
  jsonSchema<A>(JSONSchema.make(schema), {
    validate: (input) => {
      const decoded = Schema.decodeUnknownEither(schema)(input);
      return Either.isRight(decoded)
        ? { success: true, value: decoded.right }
        : { success: false, error: new Error(String(decoded.left)) };
    },
  });

const toModelMessages = (messages: ChatMessage[]): ModelMessage[] =>
  messages
    .filter(
      (message): message is ChatMessage & { role: 'user' | 'assistant' } => message.role !== 'tool',
    )
    .map((message) => ({ role: message.role, content: message.content }));

type Model = ReturnType<ReturnType<typeof createOpenAI>['chat']>;

export type GenerationSinkShape = {
  append: (type: string, data: unknown) => Effect.Effect<void>;
  emit: (type: string, data: unknown) => Effect.Effect<void>;
  save: () => Effect.Effect<void>;
  spawn: (work: Effect.Effect<void, never, never>) => Effect.Effect<void>;
};

export class GenerationSink extends Context.Tag('app/GenerationSink')<
  GenerationSink,
  GenerationSinkShape
>() {}

export class Agent extends Effect.Service<Agent>()('app/Agent', {
  effect: Effect.gen(function* () {
    const config = yield* Config;
    const pythonServer = yield* PythonServer;

    const generateTitle = (snapshot: StoredChatSnapshot, model: Model) =>
      Effect.gen(function* () {
        const title = yield* Effect.tryPromise(() =>
          generateText({
            model,
            system:
              'Create a concise title under 10 words. Describe the user request without answering it.',
            prompt: snapshot.messages
              .filter((message) => message.role !== 'tool')
              .map((message) => `${message.role}: ${message.content}`)
              .join('\n'),
          }),
        );
        const text = title.text.trim().replaceAll(/\s+/g, ' ').slice(0, 120);
        if (!text || snapshot.title !== '...') return;
        snapshot.title = text;
        yield* (yield* GenerationSink).save();
      }).pipe(
        // A title failure must not discard an otherwise successful response.
        Effect.catchAll(() => Effect.void),
      );

    const buildTools = (snapshot: StoredChatSnapshot) => {
      const ensureEnvironment = () =>
        Effect.runPromise(pythonServer.createEnvironment(snapshot.id, snapshot.dataset));
      return {
        check_environment: tool({
          description: 'Fetch the available dataframes in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ request: Schema.optional(Schema.String) })),
          execute: async () => (await ensureEnvironment()).available_dataframes,
        }),
        run_python: tool({
          description: 'Execute Python lines in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ python_code: Schema.Array(Schema.String) })),
          execute: async ({ python_code }) => {
            await ensureEnvironment();
            return (
              await Effect.runPromise(pythonServer.execute(snapshot.id, [...python_code], 'python'))
            ).outputs;
          },
        }),
        run_sql: tool({
          description: 'Execute SQL lines in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ sql_statement: Schema.Array(Schema.String) })),
          execute: async ({ sql_statement }) => {
            await ensureEnvironment();
            return (
              await Effect.runPromise(pythonServer.execute(snapshot.id, [...sql_statement], 'sql'))
            ).outputs;
          },
        }),
      };
    };

    const runGeneration = (
      snapshot: StoredChatSnapshot,
      messageRequestId: string,
    ): Effect.Effect<void, never, GenerationSink> =>
      Effect.gen(function* () {
        const sink = yield* GenerationSink;
        if (Option.isNone(config.openaiApiKey)) {
          return yield* Effect.fail(
            new HttpError({ status: 503, message: 'AI generation is not configured' }),
          );
        }
        const model = createOpenAI({ apiKey: config.openaiApiKey.value }).chat(
          Option.getOrElse(config.openaiModel, () => 'gpt-5-nano'),
        );
        if (snapshot.title === '...')
          yield* sink.spawn(
            generateTitle(snapshot, model).pipe(Effect.provideService(GenerationSink, sink)),
          );

        const result = streamText({
          model,
          system: systemPrompt,
          messages: toModelMessages(snapshot.messages),
          tools: buildTools(snapshot),
          stopWhen: isStepCount(MAX_AGENT_ITERATIONS),
        });

        let assistantId: string | undefined;
        yield* Stream.fromAsyncIterable(result.stream, (error) => error).pipe(
          Stream.runForEach((part) =>
            Match.value(part).pipe(
              Match.when(
                (value): value is typeof part & { type: 'text-delta' } =>
                  value.type === 'text-delta',
                (value) =>
                  Effect.gen(function* () {
                    if (!assistantId) {
                      assistantId = crypto.randomUUID();
                      snapshot.messages.push({
                        id: assistantId,
                        role: 'assistant',
                        content: '',
                        createdAt: Date.now(),
                      });
                    }
                    const index = snapshot.messages.findIndex(
                      (message) => message.id === assistantId,
                    );
                    if (index !== -1) {
                      const assistant = snapshot.messages[index];
                      snapshot.messages[index] = {
                        ...assistant,
                        content: assistant.content + value.text,
                      };
                    }
                    yield* sink.emit('text-delta', { id: assistantId, delta: value.text });
                  }),
              ),
              Match.when(
                (value): value is typeof part & { type: 'tool-input-start' } =>
                  value.type === 'tool-input-start',
                (value) => sink.emit('tool-params-start', { id: value.id, name: value.toolName }),
              ),
              Match.when(
                (value): value is typeof part & { type: 'tool-input-delta' } =>
                  value.type === 'tool-input-delta',
                (value) => sink.emit('tool-params-delta', { id: value.id, delta: value.delta }),
              ),
              Match.when(
                (value): value is typeof part & { type: 'tool-call' } => value.type === 'tool-call',
                (value) =>
                  sink.emit('tool-call', {
                    id: value.toolCallId,
                    name: value.toolName,
                    params: JSON.stringify(value.input),
                  }),
              ),
              Match.when(
                (value): value is typeof part & { type: 'tool-result' } =>
                  value.type === 'tool-result',
                (value) =>
                  Effect.gen(function* () {
                    const result =
                      typeof value.output === 'string'
                        ? value.output
                        : JSON.stringify(value.output);
                    snapshot.messages.push({
                      id: value.toolCallId,
                      role: 'tool',
                      content: result,
                      createdAt: Date.now(),
                      toolCallId: value.toolCallId,
                      toolName: value.toolName,
                      toolArguments: value.input,
                      toolResult: result,
                      toolFailed: false,
                    });
                    yield* sink.emit('tool-result', {
                      id: value.toolCallId,
                      name: value.toolName,
                      result,
                      isFailure: false,
                    });
                    yield* sink.save();
                  }),
              ),
              Match.when(
                (value): value is typeof part & { type: 'error' } => value.type === 'error',
                (value) => Effect.fail(value.error),
              ),
              Match.orElse(() => Effect.void),
            ),
          ),
        );
        yield* sink.append('response_done', { messageRequestId });
      }).pipe(
        Effect.catchAll((error) =>
          Effect.gen(function* () {
            const sink = yield* GenerationSink;
            yield* sink.append('response_error', {
              message: error instanceof Error ? error.message : 'Unable to generate a response',
            });
            yield* sink.append('response_done', { messageRequestId });
          }),
        ),
      );

    return { runGeneration } as const;
  }),
  dependencies: [ConfigLive, PythonServerLive],
}) {}

export const AgentLive = Agent.Default;
