import { relations } from 'drizzle-orm';
import {
  uuid,
  integer,
  serial,
  pgTable,
  text,
  timestamp,
  boolean,
  index,
  jsonb,
} from 'drizzle-orm/pg-core';

export const messageRequests = pgTable('message_requests', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => user.id, { onDelete: 'cascade' }),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  content: text('content'),
});

export const chat = pgTable('chat', {
  id: uuid('id').defaultRandom().primaryKey(),
  userId: text('user_id')
    .notNull()
    .references(() => user.id, { onDelete: 'cascade' }),
  dataset: text('dataset').notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .$onUpdate(() => /* @__PURE__ */ new Date())
    .notNull(),
  currentMessageRequest: uuid('currentMessageRequest'),
  title: text('title'),
});

export const chatRelations = relations(chat, ({ one, many }) => ({
  messages: many(chatMessage),
  user: one(user, {
    fields: [chat.userId],
    references: [user.id],
  }),
}));

// ============================================================================
// Normalized Chat History Schema
// ============================================================================

/**
 * Chat messages table - stores individual messages in a conversation.
 * Each message has a role (system, user, assistant, tool) and a sequence number.
 */
export const chatMessage = pgTable(
  'chat_message',
  {
    id: serial('id').notNull().primaryKey(),
    chatId: uuid('chat_id')
      .notNull()
      .references(() => chat.id, { onDelete: 'cascade' }),
    role: text('role').notNull().$type<'system' | 'user' | 'assistant' | 'tool'>(),
    sequence: integer('sequence').notNull(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
  },
  (table) => [
    index('chat_message_chat_id_idx').on(table.chatId),
    index('chat_message_chat_id_sequence_idx').on(table.chatId, table.sequence),
  ],
);

export const chatMessageRelations = relations(chatMessage, ({ one, many }) => ({
  chat: one(chat, {
    fields: [chatMessage.chatId],
    references: [chat.id],
  }),
  parts: many(chatMessagePart),
}));

/**
 * Message part types for the content JSONB
 */
export type TextPartContent = { text: string };
export type ToolCallPartContent = {
  id: string;
  name: string;
  params: unknown;
  providerExecuted?: boolean;
};
export type ToolResultPartContent = {
  id: string;
  name: string;
  result: unknown;
  isFailure: boolean;
  providerExecuted?: boolean;
};
export type ReasoningPartContent = { text: string };
export type FilePartContent = {
  mediaType: string;
  url?: string;
  data?: string;
};

export type MessagePartContent =
  | TextPartContent
  | ToolCallPartContent
  | ToolResultPartContent
  | ReasoningPartContent
  | FilePartContent;

/**
 * Chat message parts table - stores the content parts of each message.
 * Parts can be text, tool calls, tool results, files, or reasoning.
 */
export const chatMessagePart = pgTable(
  'chat_message_part',
  {
    id: serial('id').notNull().primaryKey(),
    messageId: integer('message_id')
      .notNull()
      .references(() => chatMessage.id, { onDelete: 'cascade' }),
    type: text('type')
      .notNull()
      .$type<'text' | 'tool-call' | 'tool-result' | 'file' | 'reasoning'>(),
    sequence: integer('sequence').notNull(),
    content: jsonb('content').notNull().$type<MessagePartContent>(),
  },
  (table) => [
    index('chat_message_part_message_id_idx').on(table.messageId),
    index('chat_message_part_message_id_sequence_idx').on(table.messageId, table.sequence),
  ],
);

export const chatMessagePartRelations = relations(chatMessagePart, ({ one }) => ({
  message: one(chatMessage, {
    fields: [chatMessagePart.messageId],
    references: [chatMessage.id],
  }),
}));

/*
  -------- Better-Auth --------
*/

export const user = pgTable('user', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  email: text('email').notNull().unique(),
  emailVerified: boolean('email_verified').default(false).notNull(),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .defaultNow()
    .$onUpdate(() => /* @__PURE__ */ new Date())
    .notNull(),
});

export const session = pgTable(
  'session',
  {
    id: text('id').primaryKey(),
    expiresAt: timestamp('expires_at').notNull(),
    token: text('token').notNull().unique(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .$onUpdate(() => /* @__PURE__ */ new Date())
      .notNull(),
    ipAddress: text('ip_address'),
    userAgent: text('user_agent'),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
  },
  (table) => [index('session_userId_idx').on(table.userId)],
);

export const account = pgTable(
  'account',
  {
    id: text('id').primaryKey(),
    accountId: text('account_id').notNull(),
    providerId: text('provider_id').notNull(),
    userId: text('user_id')
      .notNull()
      .references(() => user.id, { onDelete: 'cascade' }),
    accessToken: text('access_token'),
    refreshToken: text('refresh_token'),
    idToken: text('id_token'),
    accessTokenExpiresAt: timestamp('access_token_expires_at'),
    refreshTokenExpiresAt: timestamp('refresh_token_expires_at'),
    scope: text('scope'),
    password: text('password'),
    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .$onUpdate(() => /* @__PURE__ */ new Date())
      .notNull(),
  },
  (table) => [index('account_userId_idx').on(table.userId)],
);

export const verification = pgTable(
  'verification',
  {
    id: text('id').primaryKey(),
    identifier: text('identifier').notNull(),
    value: text('value').notNull(),
    expiresAt: timestamp('expires_at').notNull(),
    createdAt: timestamp('created_at').defaultNow().notNull(),
    updatedAt: timestamp('updated_at')
      .defaultNow()
      .$onUpdate(() => /* @__PURE__ */ new Date())
      .notNull(),
  },
  (table) => [index('verification_identifier_idx').on(table.identifier)],
);

export const userRelations = relations(user, ({ many }) => ({
  sessions: many(session),
  accounts: many(account),
  chats: many(chat),
}));

export const sessionRelations = relations(session, ({ one }) => ({
  user: one(user, {
    fields: [session.userId],
    references: [user.id],
  }),
}));

export const accountRelations = relations(account, ({ one }) => ({
  user: one(user, {
    fields: [account.userId],
    references: [user.id],
  }),
}));
