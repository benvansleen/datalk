import { Effect, Layer, pipe } from 'effect';
import * as Option from 'effect/Option';
import * as Ref from 'effect/Ref';
import * as Stream from 'effect/Stream';
import { AiError, Chat, LanguageModel, Prompt, Response } from '@effect/ai';
import { OpenAiLanguageModel } from '@effect/ai-openai';
import { DatalkToolkit, makeDatalkToolHandlers, type DatalkTools } from './DatalkTools';
import { ChatBackingPersistenceLive } from './ChatPersistence';

// ============================================================================
// System Prompt
// ============================================================================

const SYSTEM_PROMPT = `
# Instructions
- When appropriate, I must utilize the available \`run_python\` or \`run_sql\` tools to fulfill the user's request
- I will always make use of Markdown formatting to enhance my final response to the user
- I am intended to provide beautiful, synthesized results of my analyses utilizing Markdown headers, tables, blocks, etc

# Helpful tips
- I know that the most recent output of \`run_sql\` is always available via the \`sql_output\` variable within the \`run_python\` tool
- It's usually best to do complex data manipulation in SQL, then print out final calcs in Python
- The \`run_python\` tool always returns the variable names, columns, and shape of any available dataframes within my session
- The user is **probably** referring to one of the datasets uploaded into the computation environment
`.trim();

// ============================================================================
// Constants
// ============================================================================

/** Maximum number of agentic loop iterations to prevent infinite loops */
const MAX_ITERATIONS = 10;

// ============================================================================
// Stream Part Type
// ============================================================================

/**
 * Type for stream parts emitted by the DatalkAgent.
 */
export type DatalkStreamPart = Response.StreamPart<DatalkTools>;

// ============================================================================
// DatalkAgent Service
// ============================================================================

/**
 * Service for running the Datalk AI agent with tool support.
 * Uses @effect/ai Chat.Persisted for conversation history and streaming responses.
 * Implements an agentic loop that continues calling the model until no tool calls remain.
 */
export class DatalkAgent extends Effect.Service<DatalkAgent>()('app/DatalkAgent', {
  effect: Effect.gen(function* () {
    const chatPersistence = yield* Chat.Persistence;
    const languageModel = yield* LanguageModel.LanguageModel;

    /**
     * Run the agent for a given chat, returning a stream of response parts.
     * Implements an agentic loop: if the model calls tools, results are fed back
     * and the model is called again until it produces a final text response.
     *
     * @param chatId - The unique identifier for the chat
     * @param dataset - The dataset to use for the compute environment
     * @param message - The user's message to process
     * @returns A Stream of response parts that can be consumed for real-time updates
     */
    const run = (chatId: string, dataset: string, message: string) =>
      Effect.gen(function* () {
        yield* Effect.logInfo(`[Agent.run] Starting for chat ${chatId}, message: "${message.substring(0, 50)}..."`);

        // Get or create the persisted chat for this chatId
        yield* Effect.logInfo(`[Agent.run] Calling chatPersistence.getOrCreate...`);
        const chat = yield* chatPersistence.getOrCreate(chatId).pipe(
          Effect.timeout('10 seconds'),
          Effect.tapError((e) => Effect.logError(`[Agent.run] getOrCreate failed: ${e}`)),
        );
        yield* Effect.logInfo(`[Agent.run] Got chat instance`);

        // Check if this is a new chat (empty history) and set system prompt if so
        const currentHistory = yield* Ref.get(chat.history);
        yield* Effect.logInfo(`[Agent.run] Current history has ${currentHistory.content.length} messages`);

        if (currentHistory.content.length === 0) {
          // Initialize with system prompt for new chats
          yield* Ref.set(chat.history, Prompt.make([{ role: 'system', content: SYSTEM_PROMPT }]));
          yield* Effect.logInfo(`[Agent.run] Set system prompt for new chat`);
        }

        // Create the tool handlers layer for this specific chat context
        const toolHandlersLayer = makeDatalkToolHandlers(chatId, dataset);

        // Merge with LanguageModel layer so the stream has everything it needs
        const fullLayer = Layer.merge(
          toolHandlersLayer,
          Layer.succeed(LanguageModel.LanguageModel, languageModel),
        );

        /**
         * Run a single model iteration, collecting all parts.
         * Returns parts array and whether tool results were seen.
         */
        const runIteration = (iteration: number, prompt: string | readonly Prompt.Message[]) =>
          Effect.gen(function* () {
            yield* Effect.logInfo(`[runIteration ${iteration}] Calling chat.streamText`);

            const parts: DatalkStreamPart[] = [];
            let hasToolResults = false;

            // Create the stream with error logging
            const baseStream = chat.streamText({
              prompt,
              toolkit: DatalkToolkit,
            });

            yield* Effect.logInfo(`[runIteration ${iteration}] Created base stream, providing layer`);

            const stream = pipe(
              baseStream,
              Stream.provideLayer(fullLayer),
              Stream.tapError((e) =>
                Effect.logError(`[runIteration ${iteration}] Stream error: ${JSON.stringify(e, null, 2)}`),
              ),
              // Add timeout to detect hanging
              Stream.timeout('30 seconds'),
              Stream.tapError((e) =>
                Effect.logError(`[runIteration ${iteration}] After timeout - error: ${e}`),
              ),
            );

            yield* Effect.logInfo(`[runIteration ${iteration}] Starting to consume stream`);

            yield* pipe(
              Stream.runForEach(stream, (part) =>
                Effect.gen(function* () {
                  yield* Effect.logInfo(`[runIteration ${iteration}] Got part: ${part.type}`);
                  parts.push(part);
                  if (part.type === 'tool-result') {
                    hasToolResults = true;
                  }
                }),
              ),
              Effect.tapError((e) =>
                Effect.logError(`[runIteration ${iteration}] runForEach error: ${JSON.stringify(e, null, 2)}`),
              ),
              Effect.tapDefect((e) => Effect.logError(`[runIteration ${iteration}] DEFECT: ${e}`)),
            );

            yield* Effect.logInfo(`[runIteration ${iteration}] Stream complete, ${parts.length} parts, hasToolResults=${hasToolResults}`);
            return { parts, hasToolResults };
          });

        // State for the agentic loop
        interface LoopState {
          iteration: number;
          prompt: string | readonly Prompt.Message[];
        }

        /**
         * Agentic loop using Stream.unfoldEffect for proper streaming with state.
         * Each iteration collects parts, then checks if continuation is needed.
         */
        const agenticStream = pipe(
          Stream.unfoldEffect<LoopState, DatalkStreamPart[], AiError.AiError | Error, never>(
            { iteration: 1, prompt: message },
            (state): Effect.Effect<Option.Option<readonly [DatalkStreamPart[], LoopState]>, AiError.AiError | Error, never> =>
              Effect.gen(function* () {
                if (state.iteration > MAX_ITERATIONS) {
                  // This is expected when we set iteration to MAX+1 to signal completion
                  return Option.none();
                }

                yield* Effect.logInfo(`[Loop] Iteration ${state.iteration} starting`);

                const { parts, hasToolResults } = yield* runIteration(state.iteration, state.prompt);

                yield* Effect.logInfo(`[Loop] Iteration ${state.iteration} got ${parts.length} parts, hasToolResults: ${hasToolResults}`);

                // Log the types of parts we got
                const partTypes = parts.map((p) => p.type).join(', ');
                yield* Effect.logInfo(`[Loop] Part types: ${partTypes}`);

                if (hasToolResults) {
                  yield* Effect.logInfo(`[Loop] Tool results found, continuing to iteration ${state.iteration + 1}`);
                  const nextState: LoopState = { iteration: state.iteration + 1, prompt: [] };
                  return Option.some([parts, nextState] as const);
                }

                yield* Effect.logInfo(`[Loop] No tool results, finishing`);
                return parts.length > 0
                  ? Option.some([parts, { iteration: MAX_ITERATIONS + 1, prompt: [] }] as const)
                  : Option.none();
              }).pipe(Effect.catchAll((e) => Effect.fail(e instanceof Error ? e : new Error(String(e))))),
          ),
          Stream.flatMap((parts) => Stream.fromIterable(parts)),
        );

        return agenticStream;
      });

    return { run } as const;
  }),
  dependencies: [
    OpenAiLanguageModel.model('gpt-5-nano'),
    Chat.layerPersisted({ storeId: 'datalk-chats' }).pipe(Layer.provide(ChatBackingPersistenceLive)),
  ],
}) {}

export const DatalkAgentLive = DatalkAgent.Default;
