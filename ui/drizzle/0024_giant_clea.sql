ALTER TABLE "responses_api_function_call" ADD COLUMN "event_idx" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_function_result" ADD COLUMN "event_idx" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_message" ADD COLUMN "event_idx" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" ADD COLUMN "event_idx" integer NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_function_call" DROP COLUMN "created_at";--> statement-breakpoint
ALTER TABLE "responses_api_function_result" DROP COLUMN "created_at";--> statement-breakpoint
ALTER TABLE "responses_api_message" DROP COLUMN "created_at";--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" DROP COLUMN "created_at";
