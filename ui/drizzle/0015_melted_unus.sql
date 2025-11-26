CREATE TABLE "responses_api_message" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"role" text NOT NULL,
	"content" text NOT NULL
);
--> statement-breakpoint
ALTER TABLE "responses_api_message" ADD CONSTRAINT "responses_api_message_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "responses_api_session" DROP COLUMN "type";--> statement-breakpoint
ALTER TABLE "responses_api_session" DROP COLUMN "item";
