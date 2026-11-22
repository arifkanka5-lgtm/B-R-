BEGIN;

ALTER TABLE "GiftTransaction"
ADD COLUMN IF NOT EXISTS "requestId" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "GiftTransaction_sender_request_idx"
ON "GiftTransaction" ("senderId", "requestId")
WHERE "requestId" IS NOT NULL;

COMMIT;
