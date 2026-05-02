const express = require("express");
const http = require("http");
const axios = require("axios");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: {
    origin: "*",
  },
});

const PORT = process.env.PORT || 4000;
const BACKEND_URL = "https://backend-production-66b91.up.railway.app";

app.get("/health", (req, res) => {
  res.status(200).json({ ok: true });
});

const logMessage = (message, extra) => {
  if (extra !== undefined) {
    console.log(message, extra);
  } else {
    console.log(message);
  }
};

const normalizeRoom = (room) => String(room ?? "").trim();
const normalizeUsername = (username) => String(username ?? "unknown").trim();

const usersById = new Map();
const pendingPrivateInvites = new Map();

const registerSocketUser = (socket, userId, username) => {
  const numericId = Number(userId ?? 0);
  if (!numericId) {
    return;
  }

  if (username) {
    socket.data.username = normalizeUsername(username);
  }

  socket.data.userId = numericId;
  usersById.set(numericId, socket.id);
};

const findSocketByUserId = (userId) => {
  const numericId = Number(userId ?? 0);
  if (!numericId) {
    return null;
  }

  const knownSocketId = usersById.get(numericId);
  if (knownSocketId) {
    return io.sockets.sockets.get(knownSocketId) ?? null;
  }

  for (const [, activeSocket] of io.sockets.sockets) {
    if (Number(activeSocket.data.userId) === numericId) {
      usersById.set(numericId, activeSocket.id);
      return activeSocket;
    }
  }

  return null;
};

const buildPrivateRoomName = (requesterId, receiverId) => {
  const ids = [Number(requesterId ?? 0), Number(receiverId ?? 0)]
    .filter((id) => id > 0)
    .sort((a, b) => a - b);

  if (ids.length === 2) {
    return `private-${ids[0]}-${ids[1]}`;
  }

  return `private-${Date.now()}-${Math.floor(Math.random() * 10000)}`;
};

const getPrivateInviteBucket = (receiverSocketId) => {
  const existing = pendingPrivateInvites.get(receiverSocketId);
  if (existing) {
    return existing;
  }

  const created = new Map();
  pendingPrivateInvites.set(receiverSocketId, created);
  return created;
};

io.on("connection", (socket) => {
  logMessage(`[CONNECT] (${socket.id})`);

  socket.on("register-user", (payload = {}) => {
    try {
      const userId = Number(payload.userId ?? socket.data.userId ?? 0);
      const username = normalizeUsername(payload.username ?? socket.data.username);

      if (!userId) {
        logMessage(`[REGISTER-SKIP] Invalid user from ${socket.id}`, payload);
        return;
      }

      registerSocketUser(socket, userId, username);
      logMessage(`[REGISTER] ${username}`, { socketId: socket.id, userId });
    } catch (error) {
      console.error("[REGISTER-USER ERROR]", error);
    }
  });

  const handlePrivateChatRequest = (payload = {}) => {
    try {
      const rawTarget =
        typeof payload === "string" || typeof payload === "number"
          ? payload
          : payload.socketId ??
            payload.targetSocketId ??
            payload.toSocketId ??
            payload.to ??
            "";
      const targetSocketId = normalizeRoom(rawTarget);
      const requesterId = Number(
        payload.requesterId ?? payload.userId ?? socket.data.userId ?? 0
      );
      const requesterUsername = normalizeUsername(
        payload.requesterUsername ?? payload.username ?? socket.data.username
      );

      if (!targetSocketId || !requesterId) {
        logMessage("[PRIVATE-INVITE SKIP] Invalid payload", {
          targetSocketId,
          requesterId,
          requesterUsername,
        });
        return;
      }

      registerSocketUser(socket, requesterId, requesterUsername);

      const targetSocket = io.sockets.sockets.get(targetSocketId);
      if (!targetSocket) {
        logMessage("[PRIVATE-INVITE SKIP] Target not connected", {
          targetSocketId,
        });
        return;
      }

      if (targetSocket.data.userId) {
        registerSocketUser(
          targetSocket,
          targetSocket.data.userId,
          targetSocket.data.username
        );
      }

      const inviteBucket = getPrivateInviteBucket(targetSocketId);
      inviteBucket.set(requesterId, {
        requesterId,
        requesterUsername,
        requesterSocketId: socket.id,
      });

      targetSocket.emit("private-chat-invitation", {
        requesterId,
        requesterUsername,
      });

      logMessage(`[PRIVATE-INVITE] ${requesterUsername} -> ${targetSocketId}`);
    } catch (error) {
      console.error("[PRIVATE-CHAT-REQUEST ERROR]", error);
    }
  };

  socket.on("private-chat-request", handlePrivateChatRequest);
  socket.on("request-private-chat", handlePrivateChatRequest);

  const handlePrivateChatAccept = (payload = {}) => {
    try {
      const rawRequesterId =
        typeof payload === "string" || typeof payload === "number"
          ? payload
          : payload.requesterId ?? payload.userId ?? payload.fromUserId;
      const requesterId = Number(rawRequesterId ?? 0);

      if (!requesterId) {
        logMessage("[PRIVATE-ACCEPT SKIP] Invalid payload", payload);
        return;
      }

      const receiverId = Number(payload.receiverId ?? socket.data.userId ?? 0);
      const receiverUsername = normalizeUsername(
        payload.receiverUsername ?? socket.data.username
      );
      if (receiverId) {
        registerSocketUser(socket, receiverId, receiverUsername);
      }

      const requesterSocket = findSocketByUserId(requesterId);
      if (!requesterSocket) {
        logMessage("[PRIVATE-ACCEPT SKIP] Requester not connected", {
          requesterId,
        });
        return;
      }

      const requesterUsername = normalizeUsername(requesterSocket.data.username);
      const room = buildPrivateRoomName(requesterId, receiverId);

      requesterSocket.join(room);
      socket.join(room);

      requesterSocket.data.room = room;
      socket.data.room = room;

      const participants = [];
      if (requesterUsername && requesterUsername !== "unknown") {
        participants.push(requesterUsername);
      }
      if (
        receiverUsername &&
        receiverUsername !== "unknown" &&
        receiverUsername !== requesterUsername
      ) {
        participants.push(receiverUsername);
      }

      const sessionPayload = {
        room,
        participants,
      };

      requesterSocket.emit("private-chat-started", sessionPayload);
      socket.emit("private-chat-started", sessionPayload);

      const inviteBucket = pendingPrivateInvites.get(socket.id);
      if (inviteBucket) {
        inviteBucket.delete(requesterId);
        if (inviteBucket.size === 0) {
          pendingPrivateInvites.delete(socket.id);
        }
      }

      logMessage(`[PRIVATE-START] ${requesterId} <-> ${receiverId}`, {
        room,
      });
    } catch (error) {
      console.error("[PRIVATE-CHAT-ACCEPT ERROR]", error);
    }
  };

  socket.on("private-chat-accept", handlePrivateChatAccept);
  socket.on("accept-private-chat", handlePrivateChatAccept);

  socket.on("join-room", (payload = {}) => {
    try {
      const room = normalizeRoom(payload.room);
      const username = normalizeUsername(payload.username);
      const userId = Number(payload.userId ?? socket.data.userId ?? 0);

      if (!room) {
        logMessage(`[JOIN-ERROR] Invalid room from ${socket.id}`, payload);
        return;
      }

      const prevRoom = normalizeRoom(socket.data.room);
      const prevUsername = normalizeUsername(socket.data.username || username);

      // Başka bir room'daysa önce oradan çıkar
      if (prevRoom && prevRoom !== room) {
        socket.leave(prevRoom);

        socket.to(prevRoom).emit("system-message", {
          message: `${prevUsername} left ${prevRoom}`,
        });

        logMessage(`[SWITCH] ${prevUsername} left ${prevRoom}`);
      }

      // Aynı room'a tekrar join çağrısı geldiyse sorun çıkarma
      socket.join(room);
      socket.data.username = username;
      socket.data.room = room;
      socket.data.userId = userId;
      registerSocketUser(socket, userId, username);

      logMessage(`[JOIN] ${username} joined ${room}`, {
        socketId: socket.id,
        userId,
      });

      socket.to(room).emit("system-message", {
        message: `${username} joined ${room}`,
      });
    } catch (error) {
      console.error("[JOIN-ROOM ERROR]", error);
    }
  });

  socket.on("send-message", async (data = {}) => {
    try {
      const room = normalizeRoom(data.room ?? socket.data.room);
      const message = String(data.message ?? "").trim();
      const userId = Number(data.userId ?? socket.data.userId ?? 0);
      const username = normalizeUsername(data.username ?? socket.data.username);

      if (!room || !message || !userId || !username) {
        logMessage("[SEND-MESSAGE SKIPPED] Invalid payload", {
          room,
          message,
          userId,
          username,
        });
        return;
      }

      const payload = {
        room,
        userId,
        username,
        message,
        socketId: socket.id,
      };

      logMessage("POST URL:", `${BACKEND_URL}/community/messages`);
      logMessage("POST PAYLOAD:", payload);

      const response = await axios.post(
      `${BACKEND_URL}/api/community/messages`,
        payload
      );

      const savedMessage = response.data.message ?? response.data;

      if (savedMessage && typeof savedMessage === "object") {
        savedMessage.socketId = savedMessage.socketId ?? socket.id;
      }

      io.to(room).emit("new-message", savedMessage);

      logMessage(`[MESSAGE] ${username} in ${room}: ${message}`);
    } catch (error) {
      console.error(
        "Error saving message:",
        error.response?.data || error.message
      );
    }
  });

  socket.on("leave-room", (payload = {}) => {
    try {
      const room = normalizeRoom(payload.room ?? socket.data.room);
      const username = normalizeUsername(payload.username ?? socket.data.username);

      if (!room) {
        logMessage(
          `[LEAVE-SKIP] ${username} tried to leave but no active room was found.`,
          { socketId: socket.id }
        );
        return;
      }

      socket.leave(room);

      socket.to(room).emit("system-message", {
        message: `${username} left ${room}`,
      });

      logMessage(`[LEAVE] ${username} left ${room}`, {
        socketId: socket.id,
        userId: socket.data.userId,
      });

      // Leave sonrası tekrar join edebilsin diye room bilgisini temizle
      socket.data.room = null;
    } catch (error) {
      console.error("[LEAVE-ROOM ERROR]", error);
    }
  });

  socket.on("disconnect", () => {
    const username = normalizeUsername(socket.data.username);
    const room = normalizeRoom(socket.data.room);

    if (room) {
      socket.to(room).emit("system-message", {
        message: `${username} disconnected`,
      });
    }

    logMessage(`[DISCONNECT] ${username} (${socket.id})`, {
      room,
      userId: socket.data.userId,
    });

    if (socket.data.userId) {
      usersById.delete(socket.data.userId);
    }

    pendingPrivateInvites.delete(socket.id);
  });
});

server.listen(PORT, () => {
  console.log(`Socket.IO server running on port ${PORT}`);
});