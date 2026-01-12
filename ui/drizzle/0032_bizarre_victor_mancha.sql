CREATE TABLE "chat_message" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_id" uuid NOT NULL,
	"role" text NOT NULL,
	"sequence" integer NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "chat_message_part" (
	"id" serial PRIMARY KEY NOT NULL,
	"message_id" integer NOT NULL,
	"type" text NOT NULL,
	"sequence" integer NOT NULL,
	"content" jsonb NOT NULL
);
--> statement-breakpoint
DROP TABLE "chat_history" CASCADE;--> statement-breakpoint
ALTER TABLE "chat_message" ADD CONSTRAINT "chat_message_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "chat_message_part" ADD CONSTRAINT "chat_message_part_message_id_chat_message_id_fk" FOREIGN KEY ("message_id") REFERENCES "public"."chat_message"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "chat_message_chat_id_idx" ON "chat_message" USING btree ("chat_id");--> statement-breakpoint
CREATE INDEX "chat_message_chat_id_sequence_idx" ON "chat_message" USING btree ("chat_id","sequence");--> statement-breakpoint
CREATE INDEX "chat_message_part_message_id_idx" ON "chat_message_part" USING btree ("message_id");--> statement-breakpoint
CREATE INDEX "chat_message_part_message_id_sequence_idx" ON "chat_message_part" USING btree ("message_id","sequence");
