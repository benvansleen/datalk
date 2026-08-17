import { createOpenAI } from '@ai-sdk/openai';
import { Context, Effect, Either, JSONSchema, Match, Option, Schema, Stream } from 'effect';
import { generateText, isStepCount, jsonSchema, streamText, tool, type ModelMessage } from 'ai';
import { ChatMessage, HttpError } from '../types';
import type { StoredChatSnapshot } from '../cell/shared';
import { AiTelemetry, AiTelemetryLive } from './AiTelemetry';
import { Config, ConfigLive } from './Config';
import { Observability, ObservabilityLive } from './Observability';
import { PythonServer, PythonServerLive } from './PythonServer';

const MAX_AGENT_ITERATIONS = 10;

const systemPrompt = `
# Instructions
- Use run_python or run_sql whenever computation would improve the answer.
- Format answers in Markdown.
- The user is probably referring to the selected dataset.
- Plots and figures are captured and shown to the user automatically. Prefer seaborn.
  Never call matplotlib.use or switch backends, never save figures to files,
  and never call savefig. Create figures normally and call plt.show().
`.trim();

const aiSchema = <A, I>(schema: Schema.Schema<A, I, never>) =>
  jsonSchema<A>(JSONSchema.make(schema), {
    validate: (input) => {
      const decoded = Schema.decodeUnknownEither(schema)(input);
      return decoded.pipe(
        Either.match({
          onLeft: (error) => ({ success: false as const, error: new Error(String(error)) }),
          onRight: (value) => ({ success: true as const, value }),
        }),
      );
    },
  });

const parseToolArgs = (args: string): unknown => {
  try {
    return JSON.parse(args);
  } catch {
    return args;
  }
};

const INTERRUPTED_TOOL_RESULT = 'Tool execution was interrupted before a result was recorded.';

export const toModelMessages = (messages: ChatMessage[]): ModelMessage[] => {
  const toolCallIds = new Set(
    messages.flatMap((message) => (message.toolCalls ?? []).map((call) => call.toolCallId)),
  );
  const answeredToolCallIds = new Set(
    messages.flatMap((message) => (message.role === 'tool' ? [message.toolCallId] : [])),
  );
  const interruptedToolResult = (toolCallId: string, toolName: string): ModelMessage => ({
    role: 'tool',
    content: [
      {
        type: 'tool-result',
        toolCallId,
        toolName,
        output: { type: 'text', value: INTERRUPTED_TOOL_RESULT },
      },
    ],
  });
  return messages.flatMap((message) =>
    Match.value(message).pipe(
      Match.when({ role: 'user' }, (message): ModelMessage[] => [
        { role: 'user', content: message.content },
      ]),
      Match.when({ role: 'tool' }, (message): ModelMessage[] =>
        message.toolCallId && message.toolName && toolCallIds.has(message.toolCallId)
          ? [
              {
                role: 'tool',
                content: [
                  {
                    type: 'tool-result',
                    toolCallId: message.toolCallId,
                    toolName: message.toolName,
                    output: { type: 'text', value: message.content },
                  },
                ],
              },
            ]
          : [],
      ),
      Match.when({ role: 'assistant' }, (message): ModelMessage[] => {
        const content: Array<
          | {
              type: 'text';
              text: string;
            }
          | {
              type: 'tool-call';
              toolCallId: string;
              toolName: string;
              input: unknown;
            }
        > = [
          ...(message.content ? [{ type: 'text' as const, text: message.content }] : []),
          ...(message.toolCalls ?? []).map((call) => ({
            type: 'tool-call' as const,
            toolCallId: call.toolCallId,
            toolName: call.toolName,
            input: parseToolArgs(call.args),
          })),
        ];
        if (content.length === 0) return [];
        const interrupted = (message.toolCalls ?? []).filter(
          (call) => !answeredToolCallIds.has(call.toolCallId),
        );
        return [
          { role: 'assistant', content },
          ...interrupted.map((call) => interruptedToolResult(call.toolCallId, call.toolName)),
        ];
      }),
      Match.orElse(() => []),
    ),
  );
};

type Model = ReturnType<ReturnType<typeof createOpenAI>['chat']>;

export type ToolOutput = { outputs: string; images: ReadonlyArray<{ id: string; mime: string }> };

export type GenerationSinkShape = {
  append: (type: string, data: unknown) => Effect.Effect<void>;
  emit: (type: string, data: unknown) => Effect.Effect<void>;
  save: () => Effect.Effect<void>;
  saveTitle: () => Effect.Effect<void>;
  spawn: (work: Effect.Effect<void, never, never>) => Effect.Effect<void>;
  saveImages: (
    images: ReadonlyArray<{ id: string; mime: string; data: string }>,
  ) => Effect.Effect<ReadonlyArray<{ id: string; mime: string }>>;
};

export class GenerationSink extends Context.Tag('app/GenerationSink')<
  GenerationSink,
  GenerationSinkShape
>() {}

export class Agent extends Effect.Service<Agent>()('app/Agent', {
  effect: Effect.gen(function* () {
    const config = yield* Config;
    const pythonServer = yield* PythonServer;
    const aiTelemetry = yield* AiTelemetry;
    const observability = yield* Observability;

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
            telemetry: {
              isEnabled: true,
              recordInputs: false,
              recordOutputs: false,
              functionId: 'chat.title',
              integrations: [aiTelemetry.make()],
            },
          }),
        );
        const text = title.text.trim().replaceAll(/\s+/g, ' ').slice(0, 120);
        if (!text || snapshot.title !== '...') return;
        snapshot.title = text;
        yield* (yield* GenerationSink).saveTitle();
      }).pipe(
        (effect) => observability.track('app.chat.title_generation', effect),
        // A title failure must not discard an otherwise successful response.
        Effect.catchAll(() => Effect.void),
      );

    const buildTools = (snapshot: StoredChatSnapshot, sink: GenerationSinkShape) => {
      const ensureEnvironment = () =>
        Effect.runPromise(pythonServer.createEnvironment(snapshot.id, snapshot.dataset));
      const runExecution = async (
        code: string[],
        language: 'python' | 'sql',
      ): Promise<ToolOutput> => {
        try {
          await ensureEnvironment();
          const response = await Effect.runPromise(
            pythonServer.execute(snapshot.id, code, language),
          );
          const images = await Effect.runPromise(sink.saveImages(response.images));
          return { outputs: response.outputs, images };
        } catch (cause) {
          // Return the failure as a tool result so the model can narrate or retry
          // instead of the whole generation stream aborting.
          return {
            outputs: `Execution service error: ${
              cause instanceof HttpError ? cause.message : String(cause)
            }`,
            images: [],
          };
        }
      };
      return {
        check_environment: tool({
          description: 'Fetch the available dataframes in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ request: Schema.optional(Schema.String) })),
          execute: async () => {
            try {
              return (await ensureEnvironment()).available_dataframes;
            } catch (cause) {
              return `Execution service error: ${
                cause instanceof HttpError ? cause.message : String(cause)
              }`;
            }
          },
        }),
        run_python: tool({
          description: 'Execute Python lines in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ python_code: Schema.Array(Schema.String) })),
          execute: ({ python_code }) => runExecution([...python_code], 'python'),
        }),
        run_sql: tool({
          description: 'Execute SQL lines in the selected compute environment.',
          inputSchema: aiSchema(Schema.Struct({ sql_statement: Schema.Array(Schema.String) })),
          execute: ({ sql_statement }) => runExecution([...sql_statement], 'sql'),
        }),
      };
    };

    const runGeneration = (
      snapshot: StoredChatSnapshot,
      messageRequestId: string,
    ): Effect.Effect<void, never, GenerationSink> =>
      Effect.suspend(() => {
        const startedAt = performance.now();
        let firstVisibleTextAt: number | undefined;
        let textChunkCount = 0;
        let textCharacterCount = 0;
        let toolCallCount = 0;
        let toolResultCount = 0;
        const generation = Effect.gen(function* () {
          const sink = yield* GenerationSink;
          const apiKey = yield* config.openaiApiKey.pipe(
            Option.match({
              onNone: () =>
                Effect.fail(
                  new HttpError({ status: 503, message: 'AI generation is not configured' }),
                ),
              onSome: Effect.succeed,
            }),
          );
          const model = createOpenAI({ apiKey }).responses(
            Option.getOrElse(config.openaiModel, () => 'gpt-5.6-luna'),
          );
          if (snapshot.title === '...')
            yield* sink.spawn(
              generateTitle(snapshot, model).pipe(Effect.provideService(GenerationSink, sink)),
            );

          const result = streamText({
            model,
            system: systemPrompt,
            messages: toModelMessages(snapshot.messages),
            tools: buildTools(snapshot, sink),
            stopWhen: isStepCount(MAX_AGENT_ITERATIONS),
            telemetry: {
              isEnabled: true,
              recordInputs: false,
              recordOutputs: false,
              functionId: 'chat.response',
              integrations: [aiTelemetry.make()],
            },
          });

          let assistantId: Option.Option<string> = Option.none();
          yield* Stream.fromAsyncIterable(result.stream, (error) => error).pipe(
            Stream.runForEach((part) =>
              Match.value(part).pipe(
                Match.when(
                  (value): value is typeof part & { type: 'text-delta' } =>
                    value.type === 'text-delta',
                  (value) =>
                    Effect.gen(function* () {
                      textChunkCount += 1;
                      textCharacterCount += value.text.length;
                      if (firstVisibleTextAt === undefined && value.text.length > 0) {
                        firstVisibleTextAt = performance.now();
                      }
                      const id = assistantId.pipe(
                        Option.getOrElse(() => {
                          const createdId = crypto.randomUUID();
                          assistantId = Option.some(createdId);
                          snapshot.messages.push({
                            id: createdId,
                            role: 'assistant',
                            content: '',
                            createdAt: Date.now(),
                          });
                          return createdId;
                        }),
                      );
                      const index = snapshot.messages.findIndex((message) => message.id === id);
                      if (index !== -1) {
                        const assistant = snapshot.messages[index];
                        snapshot.messages[index] = {
                          ...assistant,
                          content: assistant.content + value.text,
                        };
                      }
                      yield* sink.emit('text-delta', { id, delta: value.text });
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
                  (value): value is typeof part & { type: 'tool-call' } =>
                    value.type === 'tool-call',
                  (value) =>
                    Effect.gen(function* () {
                      toolCallCount += 1;
                      const params = JSON.stringify(value.input);
                      const assistantIdOrNull = Option.getOrNull(assistantId);
                      const index =
                        assistantIdOrNull === null
                          ? -1
                          : snapshot.messages.findIndex(
                              (message) => message.id === assistantIdOrNull,
                            );
                      const toolCall = {
                        toolCallId: value.toolCallId,
                        toolName: value.toolName,
                        args: params,
                      };
                      if (index === -1) {
                        const id = crypto.randomUUID();
                        assistantId = Option.some(id);
                        snapshot.messages.push({
                          id,
                          role: 'assistant',
                          content: '',
                          createdAt: Date.now(),
                          toolCalls: [toolCall],
                        });
                      } else {
                        const assistant = snapshot.messages[index];
                        snapshot.messages[index] = {
                          ...assistant,
                          toolCalls: [...(assistant.toolCalls ?? []), toolCall],
                        };
                      }
                      yield* sink.emit('tool-call', {
                        id: value.toolCallId,
                        name: value.toolName,
                        params,
                      });
                    }),
                ),
                Match.when(
                  (value): value is typeof part & { type: 'tool-result' } =>
                    value.type === 'tool-result',
                  (value) =>
                    Effect.gen(function* () {
                      toolResultCount += 1;
                      const output = value.output;
                      const images =
                        typeof output === 'object' &&
                        output !== null &&
                        'images' in output &&
                        Array.isArray((output as { images?: unknown }).images)
                          ? (
                              output as { images: Array<{ id: string; mime: string }> }
                            ).images.filter(
                              (image): image is { id: string; mime: string } =>
                                typeof image?.id === 'string' && typeof image?.mime === 'string',
                            )
                          : [];
                      const result = typeof output === 'string' ? output : JSON.stringify(output);
                      snapshot.messages.push({
                        id: value.toolCallId,
                        role: 'tool',
                        content: result,
                        createdAt: Date.now(),
                        toolCallId: value.toolCallId,
                        toolName: value.toolName,
                        toolArguments: value.input,
                        toolResult: output,
                        toolFailed: false,
                      });
                      assistantId = Option.none();
                      yield* sink.emit('tool-result', {
                        id: value.toolCallId,
                        name: value.toolName,
                        result,
                        images,
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
        });
        return observability
          .track('app.chat.response_generation', generation, () => ({
            'gen_ai.request.model': Option.getOrElse(config.openaiModel, () => 'gpt-5-nano'),
            'chat.stream.first_visible_text_ms':
              firstVisibleTextAt === undefined ? undefined : firstVisibleTextAt - startedAt,
            'chat.stream.text_chunk_count': textChunkCount,
            'chat.stream.text_character_count': textCharacterCount,
            'chat.stream.tool_call_count': toolCallCount,
            'chat.stream.tool_result_count': toolResultCount,
          }))
          .pipe(
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
      });

    return { runGeneration } as const;
  }),
  dependencies: [ConfigLive, PythonServerLive, AiTelemetryLive, ObservabilityLive],
}) {}

export const AgentLive = Agent.Default;
