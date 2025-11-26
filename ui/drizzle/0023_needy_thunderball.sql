CREATE TABLE "responses_api_function_call" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"call_id" text NOT NULL,
	"name" text NOT NULL,
	"status" text NOT NULL,
	"arguments" text NOT NULL,
	"providerData" json NOT NULL
);
--> statement-breakpoint
ALTER TABLE "responses_api_function_call" ADD CONSTRAINT "responses_api_function_call_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;
