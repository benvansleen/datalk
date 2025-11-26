ALTER TABLE "responses_api_provider_data" ADD COLUMN "misc" json NOT NULL;--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" DROP COLUMN "contentId";--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" DROP COLUMN "type";--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" DROP COLUMN "data";--> statement-breakpoint
ALTER TABLE "responses_api_provider_data" DROP COLUMN "content";
