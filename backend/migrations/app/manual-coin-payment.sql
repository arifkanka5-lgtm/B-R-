BEGIN;

CREATE TABLE IF NOT EXISTS "CoinPaymentRequest" (
    "id" BIGSERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL
        REFERENCES "User"("id") ON DELETE RESTRICT,
    "coinAmount" BIGINT NOT NULL
        CHECK ("coinAmount" > 0),
    "priceKurus" BIGINT NOT NULL
        CHECK ("priceKurus" > 0),
    "currency" TEXT NOT NULL DEFAULT 'TRY'
        CHECK ("currency" = 'TRY'),
    "status" TEXT NOT NULL DEFAULT 'PENDING'
        CHECK ("status" IN ('PENDING', 'APPROVED', 'REJECTED')),
    "paymentReference" TEXT,
    "adminNote" TEXT,
    "reviewedBy" INTEGER
        REFERENCES "User"("id") ON DELETE RESTRICT,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "reviewedAt" TIMESTAMPTZ,
    CONSTRAINT "CoinPaymentRequest_review_consistency"
        CHECK (
            (status = 'PENDING' AND "reviewedBy" IS NULL AND "reviewedAt" IS NULL)
            OR
            (status IN ('APPROVED', 'REJECTED')
             AND "reviewedBy" IS NOT NULL
             AND "reviewedAt" IS NOT NULL)
        )
);

CREATE INDEX IF NOT EXISTS "CoinPaymentRequest_user_created_idx"
ON "CoinPaymentRequest" ("userId", "createdAt" DESC);

CREATE INDEX IF NOT EXISTS "CoinPaymentRequest_status_created_idx"
ON "CoinPaymentRequest" ("status", "createdAt" ASC);

COMMIT;
