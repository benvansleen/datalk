import { Effect, Stream } from 'effect';
import { Redis } from '../services/Redis';
import { RedisSubscriber } from '../services/RedisSubscriber';

/**
 * Chat status event types
 */
export type ChatStatusEvent =
  | { type: 'chat-created'; userId: string; chatId: string }
  | { type: 'chat-deleted'; userId: string; chatId: string }
  | { type: 'title-changed'; userId: string; chatId: string; title: string }
  | { type: 'status-changed'; userId: string; chatId: string; currentMessageId: string | null };

/**
 * Generation event types (from AI response streaming)
 */
export type GenerationEvent =
  | { type: 'response.output_text.delta'; delta: string }
  | { type: 'response.function_call_arguments.delta'; delta: string }
  | { type: 'response.function_call_arguments.done' }
  | { type: 'response_done' }
  | { type: string; [key: string]: unknown }; // Allow other event types

/**
 * Publish a chat status event to Redis
 */
export const publishChatStatus = (event: ChatStatusEvent) =>
  Effect.gen(function* () {
    const redis = yield* Redis;
    yield* redis.publish('chat-status', JSON.stringify(event));
  }).pipe(Effect.withSpan('chat.publishStatus', { attributes: { type: event.type } }));

/**
 * Publish a response generation event to Redis
 */
export const publishGenerationEvent = (messageRequestId: string, event: object) =>
  Effect.gen(function* () {
    const redis = yield* Redis;
    const chunk = JSON.stringify(event);
    yield* redis.lPush(`gen:${messageRequestId}:history`, chunk);
    yield* redis.publish(`gen:${messageRequestId}`, chunk);
  }).pipe(Effect.withSpan('chat.publishGenerationEvent'));

/**
 * Mark a generation as complete
 */
export const markGenerationComplete = (messageRequestId: string) =>
  Effect.gen(function* () {
    const redis = yield* Redis;
    yield* redis.publish(`gen:${messageRequestId}`, JSON.stringify({ type: 'response_done' }));
    yield* redis.set(`gen:${messageRequestId}:done`, '1');
  }).pipe(Effect.withSpan('chat.markGenerationComplete'));

/**
 * Get generation history (for replay when client reconnects)
 */
export const getGenerationHistory = (messageRequestId: string) =>
  Effect.gen(function* () {
    const redis = yield* Redis;
    return yield* redis.lRange(`gen:${messageRequestId}:history`, 0, -1);
  }).pipe(Effect.withSpan('chat.getGenerationHistory'));

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
      return subscriber.subscribeToChannelJson<ChatStatusEvent>('chat-status').pipe(
        Stream.filter((event) => event.userId === userId)
      );
    })
  ).pipe(Stream.withSpan('chat.subscribeChatStatus', { attributes: { userId } }));

/**
 * Subscribe to generation events for a specific message request.
 * Includes history replay for reconnecting clients.
 * 
 * The stream:
 * 1. First emits all historical events (replayed from Redis list)
 * 2. Then emits live events as they arrive via pub/sub
 * 3. Automatically ends when a 'response_done' event is received
 */
export const subscribeGenerationEvents = (messageRequestId: string) =>
  Stream.unwrap(
    Effect.gen(function* () {
      const redis = yield* Redis;
      const subscriber = yield* RedisSubscriber;

      // Get historical events (stored in reverse order, so we reverse them back)
      const history = yield* redis.lRange(`gen:${messageRequestId}:history`, 0, -1);
      const historicalEvents = history.reverse().map((chunk) => {
        try {
          return JSON.parse(chunk) as GenerationEvent;
        } catch {
          return null;
        }
      }).filter((event): event is GenerationEvent => event !== null);

      // Create stream of historical events
      const historyStream = Stream.fromIterable(historicalEvents);

      // Create stream of live events
      const liveStream = subscriber.subscribeToChannelJson<GenerationEvent>(`gen:${messageRequestId}`);

      // Concatenate history with live events, and end on 'response_done'
      return Stream.concat(historyStream, liveStream).pipe(
        Stream.takeUntil((event) => event.type === 'response_done')
      );
    })
  ).pipe(Stream.withSpan('chat.subscribeGenerationEvents', { attributes: { messageRequestId } }));
