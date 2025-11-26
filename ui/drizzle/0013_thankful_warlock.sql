CREATE TABLE "responses_api_session" (
	"chat_id" uuid PRIMARY KEY NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"type" text NOT NULL,
	"item" json NOT NULL
);
--> statement-breakpoint
ALTER TABLE "responses_api_session" ADD CONSTRAINT "responses_api_session_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;
