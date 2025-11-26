import { relations } from 'drizzle-orm';
import {
  uuid,
  integer,
  serial,
  pgTable,
  text,
  varchar,
  timestamp,
  boolean,
  index,
  json,
} from 'drizzle-orm/pg-core';

export const ResponsesApiMessageContent = pgTable('responses_api_message_content', {
  id: serial('id').notNull().primaryKey(),
  messageId: serial('message_id')
    .notNull()
    .references(() => ResponsesApiMessage.id, { onDelete: 'cascade' }),
  content: text('content').notNull(),
});

export const ResponsesApiMessage = pgTable('responses_api_message', {
  id: serial('id').notNull().primaryKey(),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  eventIdx: integer('event_idx').notNull(),
  role: text('role').notNull(),
});

export const ResponsesApiFunctionCall = pgTable('responses_api_function_call', {
  id: serial('id').notNull().primaryKey(),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  eventIdx: integer('event_idx').notNull(),
  callId: text('call_id').notNull(),
  name: text('name').notNull(),
  status: text('status').notNull(),
  arguments: text('arguments').notNull(),
  providerData: json('providerData').notNull(),
});

export const ResponsesApiFunctionResult = pgTable('responses_api_function_result', {
  id: serial('id').notNull().primaryKey(),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  eventIdx: integer('event_idx').notNull(),
  name: text('name').notNull(),
  callId: text('call_id').notNull(),
  status: text('status').notNull(),
  output: json().notNull(),
});

export const ResponsesApiProviderData = pgTable('responses_api_provider_data', {
  id: serial('id').notNull().primaryKey(),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  eventIdx: integer('event_idx').notNull(),
  misc: json().notNull(),
});

export const ResponsesApiMessageContentRelations = relations(ResponsesApiMessageContent, ({ one }) => ({
  message: one(ResponsesApiMessage, {
    fields: [ResponsesApiMessageContent.messageId],
    references: [ResponsesApiMessage.id],
  }),
}))
export const ResponsesApiMessageRelations = relations(ResponsesApiMessage, ({ one, many }) => ({
  chat: one(chat, {
    fields: [ResponsesApiMessage.chatId],
    references: [chat.id],
  }),
  messageContents: many(ResponsesApiMessageContent),
}))
export const ResponsesApiFunctionCallRelations = relations(ResponsesApiFunctionCall, ({ one }) => ({
  chat: one(chat, {
    fields: [ResponsesApiFunctionCall.chatId],
    references: [chat.id],
  }),
}));
export const ResponsesApiFunctionResultRelations = relations(ResponsesApiFunctionResult, ({ one }) => ({
  chat: one(chat, {
    fields: [ResponsesApiFunctionResult.chatId],
    references: [chat.id],
  }),
}));
export const ResponsesApiProviderDataRelations = relations(ResponsesApiProviderData, ({ one }) => ({
  chat: one(chat, {
    fields: [ResponsesApiProviderData.chatId],
    references: [chat.id],
  }),
}))


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
  createdAt: timestamp('created_at').defaultNow().notNull(),
  updatedAt: timestamp('updated_at')
    .$onUpdate(() => /* @__PURE__ */ new Date())
    .notNull(),

  title: text('title'),
});

export const message = pgTable('message', {
  id: serial('id').primaryKey(),
  chatId: uuid('chat_id')
    .notNull()
    .references(() => chat.id, { onDelete: 'cascade' }),
  createdAt: timestamp('created_at').defaultNow().notNull(),
  content: text('title').notNull(),
  type: varchar('type', { length: 128 }).notNull(),
});

export const chatRelations = relations(chat, ({ many, one }) => ({
  Rmessages: many(ResponsesApiMessage),
  messages: many(message),
  functionCalls: many(ResponsesApiFunctionCall),
  functionResults: many(ResponsesApiFunctionResult),
  providerData: many(ResponsesApiProviderData),
  user: one(user, {
    fields: [chat.userId],
    references: [user.id],
  }),
}));

export const messageRelations = relations(message, ({ one }) => ({
  chat: one(chat, {
    fields: [message.chatId],
    references: [chat.id],
  }),
}));

/*
  -------- Auth --------
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
