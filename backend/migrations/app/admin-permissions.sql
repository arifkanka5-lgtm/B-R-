BEGIN;

CREATE TABLE IF NOT EXISTS "PlatformAdmin" (
    "userId" INTEGER PRIMARY KEY
        REFERENCES "User"("id") ON DELETE CASCADE,
    "role" TEXT NOT NULL
        CHECK ("role" IN ('SUPER_ADMIN', 'FINANCE_ADMIN')),
    "createdAt" TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS "PlatformAdmin_role_idx"
ON "PlatformAdmin" ("role");

COMMIT;
