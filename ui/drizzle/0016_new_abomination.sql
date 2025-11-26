CREATE TABLE "responses_api_provider_data" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"data" json NOT NULL
);
--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" ADD CONSTRAINT "responses_api_provider_data_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;
