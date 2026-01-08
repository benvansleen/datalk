import { Effect, Layer, pipe, Queue } from 'effect';
import { Option, Ref, Stream } from 'effect';
import { Chat, LanguageModel, Prompt, Response } from '@effect/ai';
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

/** Queue capacity for streaming parts - bounded to prevent memory exhaustion */
const STREAM_QUEUE_CAPACITY = 1024;

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
     * Parts are streamed in real-time as they arrive from the model.
     *
     * @param chatId - The unique identifier for the chat
     * @param dataset - The dataset to use for the compute environment
     * @param message - The user's message to process
     * @returns A Stream of response parts that can be consumed for real-time updates
     */
    const run = (chatId: string, dataset: string, message: string) =>
      Effect.gen(function* () {
        yield* Effect.logInfo(`[Agent.run] Starting for chat ${chatId}`);

        // Get or create the persisted chat for this chatId
        const chat = yield* chatPersistence.getOrCreate(chatId).pipe(
          Effect.timeout('10 seconds'),
          Effect.tapError((e) => Effect.logError(`[Agent.run] getOrCreate failed: ${e}`)),
        );

        // Check if this is a new chat (empty history) and set system prompt if so
        const currentHistory = yield* Ref.get(chat.history);
        if (currentHistory.content.length === 0) {
          yield* Ref.set(chat.history, Prompt.make([{ role: 'system', content: SYSTEM_PROMPT }]));
        }

        // Create the tool handlers layer for this specific chat context
        const toolHandlersLayer = makeDatalkToolHandlers(chatId, dataset);
        const fullLayer = Layer.merge(
          toolHandlersLayer,
          Layer.succeed(LanguageModel.LanguageModel, languageModel),
        );

        // Create a bounded queue to push parts to for real-time streaming
        // Bounded to prevent memory exhaustion if consumer is slower than producer
        const queue = yield* Queue.bounded<DatalkStreamPart | null>(STREAM_QUEUE_CAPACITY);

        // Run the agentic loop in a background fiber, pushing parts to the queue
        const agenticLoop = Effect.gen(function* () {
          let iteration = 0;
          let prompt: string | readonly Prompt.Message[] = message;
          let hasToolResults = true; // Start true to enter loop

          while (hasToolResults && iteration < MAX_ITERATIONS) {
            iteration++;
            hasToolResults = false;

            yield* Effect.logInfo(`[Agent] Iteration ${iteration} starting`);

            const stream = pipe(
              chat.streamText({
                prompt,
                toolkit: DatalkToolkit,
              }),
              Stream.provideLayer(fullLayer),
              Stream.timeout('60 seconds'),
            );

            // Stream parts and push each one to the queue immediately
            yield* Stream.runForEach(stream, (part) =>
              Effect.gen(function* () {
                // Push part to queue for immediate consumption
                yield* Queue.offer(queue, part);

                // Track if we got tool results
                if (part.type === 'tool-result') {
                  hasToolResults = true;
                }
              }),
            );

            yield* Effect.logInfo(
              `[Agent] Iteration ${iteration} complete, hasToolResults: ${hasToolResults}`,
            );

            // If continuing, use empty prompt (history already updated)
            prompt = [];
          }

          // Signal end of stream
          yield* Queue.offer(queue, null);
          yield* Effect.logInfo(`[Agent] Agentic loop complete after ${iteration} iteration(s)`);
        }).pipe(
          Effect.catchAll((e) =>
            Effect.gen(function* () {
              yield* Effect.logError(`[Agent] Error in agentic loop: ${e}`);
              yield* Queue.offer(queue, null);
            }),
          ),
        );

        // Fork the agentic loop to run in background
        // Using fork (not forkDaemon) ties the fiber to the current scope,
        // so it will be interrupted if the consumer disconnects or errors
        yield* Effect.fork(agenticLoop);

        // Return a stream that reads from the queue
        const outputStream: Stream.Stream<DatalkStreamPart, never, never> =
          Stream.repeatEffectOption(
            Effect.gen(function* () {
              const part = yield* Queue.take(queue);
              if (part === null) {
                // End of stream signal
                return yield* Effect.fail(Option.none());
              }
              return part;
            }).pipe(Effect.mapError(() => Option.none())),
          ).pipe(Stream.catchAll(() => Stream.empty));

        return outputStream;
      });

    return { run } as const;
  }),
  dependencies: [
    OpenAiLanguageModel.model('gpt-5-nano'),
    Chat.layerPersisted({ storeId: 'datalk-chats' }).pipe(
      Layer.provide(ChatBackingPersistenceLive),
    ),
  ],
}) {}

export const DatalkAgentLive = DatalkAgent.Default;
