-- CreateTable
CREATE TABLE "community_messages" (
    "id" SERIAL NOT NULL,
    "room" TEXT NOT NULL,
    "userId" INTEGER NOT NULL,
    "username" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "community_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "community_room_sessions" (
    "id" SERIAL NOT NULL,
    "userId" INTEGER NOT NULL,
    "room" TEXT NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "leftAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "community_room_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "community_messages_room_createdAt_idx" ON "community_messages"("room", "createdAt");

-- CreateIndex
CREATE INDEX "community_messages_userId_idx" ON "community_messages"("userId");

-- CreateIndex
CREATE INDEX "community_room_sessions_room_idx" ON "community_room_sessions"("room");

-- CreateIndex
CREATE INDEX "community_room_sessions_userId_idx" ON "community_room_sessions"("userId");
