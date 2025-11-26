CREATE TABLE "responses_api_function_result" (
	"id" serial PRIMARY KEY NOT NULL,
	"chat_id" uuid NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"name" text NOT NULL,
	"call_id" text NOT NULL,
	"status" text NOT NULL,
	"output" json NOT NULL
);
--> statement-breakpoint
ALTER TABLE "responses_api_function_result" ADD CONSTRAINT "responses_api_function_result_chat_id_chat_id_fk" FOREIGN KEY ("chat_id") REFERENCES "public"."chat"("id") ON DELETE cascade ON UPDATE no action;
