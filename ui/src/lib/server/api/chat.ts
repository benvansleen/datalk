import { Effect, Fiber, Stream } from 'effect';
import type { Scope } from 'effect';
import { Redis } from '../services/Redis';
import { RedisStreamReader } from '../services/RedisStreamReader';
import { RedisSubscriber } from '../services/RedisSubscriber';
import { RedisError } from '../errors';

/**
 * Chat status event types
 */
export type ChatStatusEvent =
  | { type: 'chat-created'; userId: string; chatId: string }
  | { type: 'chat-deleted'; userId: string; chatId: string }
  | { type: 'title-changed'; userId: string; chatId: string; title: string }
  | { type: 'status-changed'; userId: string; chatId: string; currentMessageId: string | null };

/**
 * Generation event types (from @effect/ai response streaming)
 * These match the Response.StreamPart types from @effect/ai
 */
export type GenerationEvent =
  // Text streaming
  | { type: 'text-start'; id: string }
  | { type: 'text-delta'; id: string; delta: string }
  | { type: 'text-end'; id: string }
  // Tool parameter streaming
  | { type: 'tool-params-start'; id: string; name: string }
  | { type: 'tool-params-delta'; id: string; delta: string }
  | { type: 'tool-params-end'; id: string }
  // Tool call and result
  | { type: 'tool-call'; id: string; name: string; params: unknown }
  | { type: 'tool-result'; id: string; name: string; result: unknown; isFailure: boolean }
  // Finish and metadata
  | { type: 'finish'; reason: string }
  | { type: 'response_done' }
  | { type: 'response_error'; message: string }
  // Allow other event types for forward compatibility
  | { type: string; [key: string]: unknown };

/**
 * Publish a chat status event to Redis
 */
export const publishChatStatus = (event: ChatStatusEvent) =>
  Effect.gen(function* () {
    const redis = yield* Redis;
    yield* redis.publish('chat-status', JSON.stringify(event));
  }).pipe(
    Effect.withSpan('chat.status.publish', {
      attributes: {
        'messaging.system': 'redis',
        'messaging.operation': 'publish',
        'messaging.destination': 'chat-status',
        'chat.status.type': event.type,
      },
    }),
  );

// ============================================================================
// Generation Events (using Redis Streams for reliable delivery)
// ============================================================================

const GENERATION_STREAM_MAX_LEN = 10000;
const GENERATION_STREAM_TTL_SECONDS = 3600; // 1 hour

/**
 * Get the Redis Stream key for a generation.
 */
const generationStreamKey = (messageRequestId: string) => `gen:${messageRequestId}:stream`;

/**
 * Publish a response generation event to Redis Stream.
 * Uses XADD with approximate MAXLEN trimming to bound memory.
 */
export const publishGenerationEvent = (messageRequestId: string, event: object) => {
  const streamKey = generationStreamKey(messageRequestId);
  return Effect.gen(function* () {
    const redis = yield* Redis;
    yield* redis.xAdd(
      streamKey,
      { event: JSON.stringify(event) },
      { maxLen: GENERATION_STREAM_MAX_LEN },
    );
  }).pipe(
    Effect.withSpan('chat.generation.publish', {
      attributes: {
        'messaging.system': 'redis',
        'messaging.operation': 'publish',
        'messaging.destination': streamKey,
        'chat.message_request.id': messageRequestId,
      },
    }),
  );
};

/**
 * Mark a generation as complete.
 * Adds the response_done event and sets a TTL on the stream for cleanup.
 */
export const markGenerationComplete = (messageRequestId: string) => {
  const streamKey = generationStreamKey(messageRequestId);
  return Effect.gen(function* () {
    const redis = yield* Redis;
    yield* redis.xAdd(streamKey, { event: JSON.stringify({ type: 'response_done' }) });
    yield* redis.expire(streamKey, GENERATION_STREAM_TTL_SECONDS);
  }).pipe(
    Effect.withSpan('chat.generation.complete', {
      attributes: {
        'messaging.system': 'redis',
        'messaging.operation': 'publish',
        'messaging.destination': streamKey,
        'chat.message_request.id': messageRequestId,
        'chat.generation.completed': true,
      },
    }),
  );
};

// ============================================================================
// Stream-based subscriptions for SSE endpoints
// ============================================================================

/**
 * Subscribe to chat status events for a specific user.
 * Returns a Stream that emits ChatStatusEvent objects filtered by userId.
 */
export const subscribeChatStatus = (userId: string) =>
  Stream.unwrap(
    Effect.gen(function* () {
      const subscriber = yield* RedisSubscriber;
      return subscriber
        .subscribeToChannelJson<ChatStatusEvent>('chat-status')
        .pipe(Stream.filter((event) => event.userId === userId));
    }),
  ).pipe(
    Stream.withSpan('chat.status.subscribe', {
      attributes: {
        'messaging.system': 'redis',
        'messaging.operation': 'subscribe',
        'messaging.destination': 'chat-status',
        'chat.user_id': userId,
      },
    }),
  );

/**
 * Parse a generation event from a JSON string.
 * Returns null if parsing fails.
 */
const parseGenerationEvent = (json: string): GenerationEvent | null => {
  try {
    return JSON.parse(json) as GenerationEvent;
  } catch {
    return null;
  }
};

/**
 * Subscribe to generation events for a specific message request.
 * Uses Redis Streams for reliable delivery with no race conditions.
 *
 * The stream:
 * 1. First emits all historical events (via XRANGE)
 * 2. Then emits live events as they arrive (via blocking XREAD)
 * 3. Automatically ends when a 'response_done' event is received
 *
 * This approach eliminates the race condition between history replay and live
 * subscription because Redis Stream IDs are monotonically increasing - XREAD
 * continues exactly where XRANGE left off with no gap.
 */
export const subscribeGenerationEvents = (messageRequestId: string) =>
  Stream.unwrap(
    Effect.gen(function* () {
      const streamKey = generationStreamKey(messageRequestId);

      // Read all existing entries from the stream
      const redis = yield* Redis;
      const history = yield* redis.xRange(streamKey, '-', '+');

      // Track the last ID we've seen (for continuing with XREAD)
      // If no history, start from '0' to get all future entries
      let lastId = history.length > 0 ? history[history.length - 1].id : '0';

      // Parse historical events
      const historicalEvents = history
        .map((entry) => parseGenerationEvent(entry.message.event))
        .filter((event): event is GenerationEvent => event !== null);

      // Check if generation is already complete (response_done in history)
      const isComplete = historicalEvents.some((e) => e.type === 'response_done');
      if (isComplete) {
        return Stream.fromIterable(historicalEvents);
      }

      // Create stream of historical events
      const historyStream = Stream.fromIterable(historicalEvents);

      // Create live stream using XREAD with a dedicated connection.
      // Uses asyncScoped for proper resource management and clean shutdown.
      const liveStream = Stream.asyncScoped<
        GenerationEvent,
        RedisError,
        Scope.Scope | RedisStreamReader
      >(
        (emit) =>
          Effect.gen(function* () {
            yield* Effect.logDebug(`Creating Redis Stream reader for: ${streamKey}`);

            // Mutable flag for synchronous shutdown detection in catch handlers
            let isShuttingDown = false;

            const streamReader = yield* RedisStreamReader;

            // Register finalizer to signal shutdown and clean up
            yield* Effect.addFinalizer(() =>
              Effect.gen(function* () {
                yield* Effect.logDebug(`Shutting down Redis Stream reader for: ${streamKey}`);
                // Set flag so the read loop knows to exit gracefully
                isShuttingDown = true;
              }),
            );

            // Blocking read loop - runs in background fiber
            const readLoop = Effect.gen(function* () {
              while (!isShuttingDown) {
                const result = yield* streamReader.readBlocking({
                  key: streamKey,
                  id: lastId,
                  block: 1000,
                  count: 100,
                  suppressErrors: () => isShuttingDown,
                });

                // Check shutdown again after blocking call returns
                if (isShuttingDown) {
                  break;
                }

                if (result && result.length > 0) {
                  const messages = result[0].messages;
                  for (const entry of messages) {
                    const event = parseGenerationEvent(entry.message.event);
                    if (event) {
                      emit.single(event);
                    }
                    lastId = entry.id;
                  }
                }
              }
              // Signal end of stream when loop exits
              yield* Effect.promise(() => emit.end());
            });

            // Fork the read loop and ensure it's interrupted on scope close
            const fiber = yield* Effect.fork(readLoop);
            yield* Effect.addFinalizer(() => Fiber.interrupt(fiber));
          }),
        { bufferSize: 256, strategy: 'sliding' },
      ).pipe(
        Stream.withSpan('chat.generation.subscribe.live', {
          attributes: {
            'messaging.system': 'redis',
            'messaging.operation': 'receive',
            'messaging.destination': streamKey,
            'chat.message_request.id': messageRequestId,
          },
        }),
      );

      // Concatenate history with live events, and end on 'response_done'
      return Stream.concat(historyStream, liveStream).pipe(
        Stream.takeUntil((event) => event.type === 'response_done'),
      );
    }),
  ).pipe(
    Stream.withSpan('chat.generation.subscribe', {
      attributes: {
        'messaging.system': 'redis',
        'messaging.operation': 'subscribe',
        'messaging.destination': generationStreamKey(messageRequestId),
        'chat.message_request.id': messageRequestId,
      },
    }),
  );
