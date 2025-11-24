ALTER TABLE "chat" ALTER COLUMN "id" SET DATA TYPE text;--> statement-breakpoint
ALTER TABLE "message" ALTER COLUMN "id" SET DATA TYPE text;--> statement-breakpoint
ALTER TABLE "message" ALTER COLUMN "chat_id" SET DATA TYPE text;