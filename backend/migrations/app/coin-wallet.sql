BEGIN;

CREATE TABLE IF NOT EXISTS "Wallet" (
    "id" SERIAL PRIMARY KEY,
    "userId" INTEGER NOT NULL UNIQUE
        REFERENCES "User"("id") ON DELETE RESTRICT,
    "balance" BIGINT NOT NULL DEFAULT 0
        CHECK ("balance" >= 0),
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    "updatedAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS "CoinTransaction" (
    "id" SERIAL PRIMARY KEY,
    "walletId" INTEGER NOT NULL
        REFERENCES "Wallet"("id") ON DELETE RESTRICT,
    "userId" INTEGER NOT NULL
        REFERENCES "User"("id") ON DELETE RESTRICT,
    "type" TEXT NOT NULL,
    "amount" BIGINT NOT NULL CHECK ("amount" > 0),
    "balanceAfter" BIGINT NOT NULL CHECK ("balanceAfter" >= 0),
    "description" TEXT,
    "referenceId" TEXT UNIQUE,
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "CoinTransaction_user_created_idx"
ON "CoinTransaction" ("userId", "createdAt" DESC);

CREATE INDEX IF NOT EXISTS "CoinTransaction_wallet_created_idx"
ON "CoinTransaction" ("walletId", "createdAt" DESC);

COMMIT;
