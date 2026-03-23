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
const BACKEND_URL = "http://localhost:3001";

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

io.on("connection", (socket) => {
  logMessage(`[CONNECT] (${socket.id})`);

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
      };

      logMessage("POST URL:", `${BACKEND_URL}/community/messages`);
      logMessage("POST PAYLOAD:", payload);

      const response = await axios.post(
      `${BACKEND_URL}/api/community/messages`,
        payload
      );

      const savedMessage = response.data.message ?? response.data;

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
  });
});

server.listen(PORT, () => {
  console.log(`Socket.IO server running on port ${PORT}`);
});