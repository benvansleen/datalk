import { Effect } from 'effect';
import { Redis } from '../services/Redis';

/**
 * Chat status event types
 */
export type ChatStatusEvent =
  | { type: 'chat-created'; userId: string; chatId: string }
  | { type: 'chat-deleted'; userId: string; chatId: string }
  | { type: 'title-changed'; userId: string; chatId: string; title: string }
  | { type: 'status-changed'; userId: string; chatId: string; currentMessageId: string | null };

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
