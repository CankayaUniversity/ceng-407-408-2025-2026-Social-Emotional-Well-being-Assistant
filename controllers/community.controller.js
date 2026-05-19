const prisma = require("../src/prisma");

const joinCommunityRoom = async (req, res) => {
  try {
    const { room } = req.body;
    const userId = Number(req.user?.id);

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Yetkisiz işlem.",
      });
    }

    if (!room) {
      return res.status(400).json({
        success: false,
        error: "room alanı zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = userId;

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
    const { room, message, username } = req.body;
    const userId = Number(req.user?.id);

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Yetkisiz işlem.",
      });
    }

    if (!room || !message || !String(message).trim()) {
      return res.status(400).json({
        success: false,
        error: "room ve message alanları zorunludur.",
      });
    }

    if (!username || !String(username).trim()) {
      return res.status(400).json({
        success: false,
        error: "username alanı zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = userId;
    const normalizedMessage = String(message).trim();

    const user = await prisma.user.findUnique({
      where: { id: normalizedUserId },
      select: { name: true, email: true },
    });

    if (!user) {
      return res.status(404).json({
        success: false,
        error: "Kullanıcı bulunamadı.",
      });
    }

    const resolvedUsername = String(username).trim();

    const savedMessage = await prisma.communityMessage.create({
      data: {
        room: normalizedRoom,
        userId: normalizedUserId,
        username: resolvedUsername,
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
    const { room } = req.query;
    const userId = Number(req.user?.id);

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Yetkisiz işlem.",
      });
    }

    if (!room) {
      return res.status(400).json({
        success: false,
        error: "room alanı zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = userId;

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

    const userIds = [...new Set(messages.map((msg) => msg.userId))];
    const preferences = await prisma.userPreferences.findMany({
      where: {
        userId: { in: userIds },
      },
      select: {
        userId: true,
        nickname: true,
      },
    });

    const nicknameByUserId = new Map(
      preferences.map((pref) => [pref.userId, pref.nickname]),
    );

    const sanitizedMessages = messages.map((msg) => {
      const nickname = nicknameByUserId.get(msg.userId);
      return {
        ...msg,
        username: (nickname && String(nickname).trim()) || "Anonim",
      };
    });

    return res.status(200).json({
      success: true,
      joinedAt: latestSession.joinedAt,
      messages: sanitizedMessages,
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
    const { room } = req.body;
    const userId = Number(req.user?.id);

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Yetkisiz işlem.",
      });
    }

    if (!room) {
      return res.status(400).json({
        success: false,
        error: "room alanı zorunludur.",
      });
    }

    const normalizedRoom = String(room).trim();
    const normalizedUserId = userId;

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

const getJoinedCommunityRooms = async (req, res) => {
  try {
    const userId = Number(req.user?.id);

    if (!userId) {
      return res.status(401).json({
        success: false,
        error: "Yetkisiz işlem.",
      });
    }

    const sessions = await prisma.communityRoomSession.findMany({
      where: {
        userId,
        leftAt: null,
      },
      orderBy: {
        joinedAt: "desc",
      },
      select: {
        room: true,
        joinedAt: true,
      },
    });

    const rooms = sessions
      .map((session) => ({
        room: String(session.room || "").trim(),
        joinedAt: session.joinedAt,
      }))
      .filter((entry) => entry.room.length > 0);

    return res.status(200).json({
      success: true,
      rooms,
    });
  } catch (error) {
    console.error("getJoinedCommunityRooms error:", error);
    return res.status(500).json({
      success: false,
      error: "Katıldığınız odalar alınamadı.",
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
  getJoinedCommunityRooms,
  cleanupOldMessages,
};