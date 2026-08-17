import { Schema } from 'effect';
import {
  ChatMessage as ChatMessageSchema,
  GenerationEvent as GenerationEventSchema,
  type ChatMessage,
  type ChatSummary,
  type Env,
  type GenerationEvent,
} from '../types';

export const jsonHeaders = {
  'content-type': 'application/json',
  'cache-control': 'no-store',
};

export const KEY_SNAPSHOT = 'snapshot';
export const KEY_CHAT_ID = 'chat-id';

type ChatSnapshotFields = {
  id: string;
  userId: string;
  dataset: string;
  title: string;
  deleted: boolean;
  createdAt: number;
  updatedAt: number;
  messages: ChatMessage[];
  events: GenerationEvent[];
};

export type GenerationState =
  | { status: 'idle' }
  | { status: 'pending'; requestId: string }
  | {
      status: 'running';
      requestId: string;
      leaseId: string;
      leaseExpiresAt: number;
    };

export type GenerationTransition =
  | { type: 'submit'; requestId: string }
  | { type: 'claim'; leaseId: string; leaseExpiresAt: number; now: number }
  | { type: 'renew'; leaseId: string; leaseExpiresAt: number; now: number }
  | { type: 'complete'; leaseId: string; now: number }
  | { type: 'cancel' };

export const transitionGeneration = (
  state: GenerationState,
  transition: GenerationTransition,
): GenerationState | null => {
  switch (transition.type) {
    case 'submit':
      return state.status === 'idle'
        ? { status: 'pending', requestId: transition.requestId }
        : null;
    case 'claim':
      return state.status === 'pending' ||
        (state.status === 'running' && state.leaseExpiresAt <= transition.now)
        ? {
            status: 'running',
            requestId: state.requestId,
            leaseId: transition.leaseId,
            leaseExpiresAt: transition.leaseExpiresAt,
          }
        : null;
    case 'renew':
      return state.status === 'running' &&
        state.leaseId === transition.leaseId &&
        state.leaseExpiresAt > transition.now
        ? { ...state, leaseExpiresAt: transition.leaseExpiresAt }
        : null;
    case 'complete':
      return state.status === 'running' &&
        state.leaseId === transition.leaseId &&
        state.leaseExpiresAt > transition.now
        ? { status: 'idle' }
        : null;
    case 'cancel':
      return { status: 'idle' };
  }
};

export type StoredChatSnapshot = ChatSnapshotFields & { generation: GenerationState };

export type ExternalChatSnapshot = ChatSnapshotFields & {
  generating: boolean;
  currentMessageRequestId: string | null;
};

export const HydratedChatSnapshot = Schema.Struct({
  id: Schema.String,
  userId: Schema.String,
  dataset: Schema.String,
  title: Schema.String,
  deleted: Schema.Boolean,
  generating: Schema.Boolean,
  currentMessageRequestId: Schema.NullOr(Schema.String),
  createdAt: Schema.Number,
  updatedAt: Schema.Number,
  messages: Schema.Array(ChatMessageSchema),
  events: Schema.optional(Schema.Array(GenerationEventSchema)),
});
export type HydratedChatSnapshot = typeof HydratedChatSnapshot.Type;

export const emptySnapshot = (id: string, userId: string, dataset: string): StoredChatSnapshot => ({
  id,
  userId,
  dataset,
  title: '...',
  deleted: false,
  generation: { status: 'idle' },
  createdAt: Date.now(),
  updatedAt: Date.now(),
  messages: [],
  events: [],
});

export const snapshotFromHydration = (snapshot: HydratedChatSnapshot): StoredChatSnapshot => {
  const { generating, currentMessageRequestId, ...fields } = snapshot;
  return {
    ...fields,
    messages: [...fields.messages],
    events: [...(fields.events ?? [])],
    generation:
      generating && currentMessageRequestId
        ? { status: 'pending', requestId: currentMessageRequestId }
        : { status: 'idle' },
  };
};

export const generationRequestId = (generation: GenerationState): string | null =>
  generation.status === 'idle' ? null : generation.requestId;

export const externalSnapshotOf = (snapshot: StoredChatSnapshot): ExternalChatSnapshot => {
  const { generation, ...fields } = snapshot;
  return {
    ...fields,
    generating: generation.status !== 'idle',
    currentMessageRequestId: generationRequestId(generation),
  };
};

export const summaryOf = (snapshot: StoredChatSnapshot): ChatSummary => ({
  id: snapshot.id,
  dataset: snapshot.dataset,
  title: snapshot.title,
  updatedAt: snapshot.events.at(-1)?.createdAt ?? 0,
  generating: snapshot.generation.status !== 'idle',
});

export const isInternalRequest = (request: Request, env: Env) =>
  request.headers.get('x-datalk-internal-secret') === env.INTERNAL_CELL_SECRET;

export const internalHeaders = (env: Env, userId: string, chatId?: string): HeadersInit => ({
  ...jsonHeaders,
  'x-datalk-internal-secret': env.INTERNAL_CELL_SECRET,
  'x-datalk-user-id': userId,
  ...(chatId ? { 'x-datalk-chat-id': chatId } : {}),
});
