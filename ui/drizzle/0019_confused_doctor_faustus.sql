ALTER TABLE "responses_api_provider_data" ADD COLUMN "contentId" text NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" ADD COLUMN "type" text NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" ADD COLUMN "content" json NOT NULL;
