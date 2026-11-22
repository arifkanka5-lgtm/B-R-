CREATE TABLE IF NOT EXISTS "RoomSeat" (
    "id" SERIAL PRIMARY KEY,
    "roomId" INTEGER NOT NULL
        REFERENCES "Room"("id") ON DELETE CASCADE,
    "userId" INTEGER
        REFERENCES "User"("id") ON DELETE SET NULL,
    "seatNumber" INTEGER NOT NULL,
    "isLocked" BOOLEAN NOT NULL DEFAULT FALSE,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "RoomSeat_roomId_seatNumber_key"
        UNIQUE ("roomId", "seatNumber")
);

CREATE UNIQUE INDEX IF NOT EXISTS
    "RoomSeat_roomId_userId_key"
    ON "RoomSeat" ("roomId", "userId")
    WHERE "userId" IS NOT NULL;

ALTER TABLE "RoomSeat"
ADD CONSTRAINT "RoomSeat_seatNumber_positive"
CHECK ("seatNumber" > 0);
