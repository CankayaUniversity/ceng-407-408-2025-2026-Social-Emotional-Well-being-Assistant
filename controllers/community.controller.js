const prisma = require("../src/prisma");

const joinCommunityRoom = async (req, res) => {
  try {
    const { userId, room } = req.body;

    if (!userId || !room) {
      return res.status(400).json({
        success: false,
        error: "userId ve room alanları zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = Number(userId);

    let session = await prisma.communityRoomSession.findFirst({
      where: {
        userId: normalizedUserId,
        room: normalizedRoom,
        leftAt: null,
      },
      orderBy: {
        joinedAt: "desc",
      },
    });

    if (!session) {
      session = await prisma.communityRoomSession.create({
        data: {
          userId: normalizedUserId,
          room: normalizedRoom,
          joinedAt: new Date(),
          leftAt: null,
        },
      });
    }

    return res.status(200).json({
      success: true,
      session,
    });
  } catch (error) {
    console.error("joinCommunityRoom error:", error);
    return res.status(500).json({
      success: false,
      error: "Room join işlemi başarısız.",
    });
  }
};

const createMessage = async (req, res) => {
  try {
    const { room, userId, username, message } = req.body;

    if (!room || !userId || !username || !message || !String(message).trim()) {
      return res.status(400).json({
        success: false,
        error: "room, userId, username ve message alanları zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = Number(userId);
    const normalizedUsername = String(username).trim();
    const normalizedMessage = String(message).trim();

    const savedMessage = await prisma.communityMessage.create({
      data: {
        room: normalizedRoom,
        userId: normalizedUserId,
        username: normalizedUsername,
        message: normalizedMessage,
      },
    });

    return res.status(201).json({
      success: true,
      message: savedMessage,
    });
  } catch (error) {
    console.error("createMessage error:", error);
    return res.status(500).json({
      success: false,
      error: "Mesaj kaydedilemedi.",
    });
  }
};

const getRoomMessages = async (req, res) => {
  try {
    const { room, userId } = req.query;

    if (!room || !userId) {
      return res.status(400).json({
        success: false,
        error: "room ve userId alanları zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = Number(userId);

    const latestSession = await prisma.communityRoomSession.findFirst({
      where: {
        userId: normalizedUserId,
        room: normalizedRoom,
      },
      orderBy: {
        joinedAt: "desc",
      },
    });

    if (!latestSession) {
      return res.status(200).json({
        success: true,
        joinedAt: null,
        messages: [],
      });
    }

    const messages = await prisma.communityMessage.findMany({
      where: {
        room: normalizedRoom,
        createdAt: {
          gte: latestSession.joinedAt,
        },
      },
      orderBy: {
        createdAt: "asc",
      },
    });

    return res.status(200).json({
      success: true,
      joinedAt: latestSession.joinedAt,
      messages,
    });
  } catch (error) {
    console.error("getRoomMessages error:", error);
    return res.status(500).json({
      success: false,
      error: "Mesajlar alınamadı.",
    });
  }
};

const leaveCommunityRoom = async (req, res) => {
  try {
    const { userId, room } = req.body;

    if (!userId || !room) {
      return res.status(400).json({
        success: false,
        error: "userId ve room alanları zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = Number(userId);

    const activeSession = await prisma.communityRoomSession.findFirst({
      where: {
        userId: normalizedUserId,
        room: normalizedRoom,
        leftAt: null,
      },
      orderBy: {
        joinedAt: "desc",
      },
    });

    if (!activeSession) {
      return res.status(200).json({
        success: true,
        message: "Aktif room session bulunamadı ama kullanıcı çıkmış sayıldı.",
      });
    }

    await prisma.communityRoomSession.update({
      where: {
        id: activeSession.id,
      },
      data: {
        leftAt: new Date(),
      },
    });

    return res.status(200).json({
      success: true,
      message: "Room'dan çıkıldı.",
    });
  } catch (error) {
    console.error("leaveCommunityRoom error:", error);
    return res.status(500).json({
      success: false,
      error: "Leave işlemi başarısız.",
    });
  }
};

const getOpenRooms = async (req, res) => {
  try {
    const activeSessions = await prisma.communityRoomSession.findMany({
      where: {
        leftAt: null,
      },
      orderBy: {
        joinedAt: "desc",
      },
      select: {
        room: true,
      },
    });

    const uniqueRooms = [
      ...new Set(
        activeSessions
          .map((item) => String(item.room || "").trim())
          .filter((room) => room.length > 0)
      ),
    ];

    return res.status(200).json({
      success: true,
      rooms: uniqueRooms,
    });
  } catch (error) {
    console.error("getOpenRooms error:", error);
    return res.status(500).json({
      success: false,
      error: "Açık odalar alınamadı.",
    });
  }
};

const cleanupOldMessages = async (req, res) => {
  try {
    const cutoffDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const result = await prisma.communityMessage.deleteMany({
      where: {
        createdAt: {
          lt: cutoffDate,
        },
      },
    });

    return res.status(200).json({
      success: true,
      message: "Eski mesajlar silindi.",
      deletedCount: result.count,
    });
  } catch (error) {
    console.error("cleanupOldMessages error:", error);
    return res.status(500).json({
      success: false,
      error: "Eski mesajlar silinemedi.",
    });
  }
};

module.exports = {
  joinCommunityRoom,
  createMessage,
  getRoomMessages,
  leaveCommunityRoom,
  getOpenRooms,
  cleanupOldMessages,
};