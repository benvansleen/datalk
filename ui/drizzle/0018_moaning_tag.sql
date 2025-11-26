CREATE TABLE "responses_api_message_content" (
	"id" serial PRIMARY KEY NOT NULL,
	"message_id" serial NOT NULL,
	"content" text NOT NULL
);
--> statement-breakpoint
DROP TABLE "responses_api_session" CASCADE;--> statement-breakpoint
ALTER TABLE "responses_api_message_content" ADD CONSTRAINT "responses_api_message_content_message_id_responses_api_message_id_fk" FOREIGN KEY ("message_id") REFERENCES "public"."responses_api_message"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "responses_api_message" DROP COLUMN "content";
