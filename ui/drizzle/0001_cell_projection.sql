ALTER TABLE "chat" ADD COLUMN "deleted_at" timestamp;
--> statement-breakpoint
CREATE TABLE "cell_projection_ledger" (
	"cell_kind" text NOT NULL,
	"cell_id" text NOT NULL,
	"last_sequence" bigint DEFAULT 0 NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	PRIMARY KEY ("cell_kind", "cell_id")
);
--> statement-breakpoint
CREATE INDEX "chat_active_user_updated_idx" ON "chat" USING btree ("user_id", "updated_at" DESC) WHERE "deleted_at" IS NULL;
