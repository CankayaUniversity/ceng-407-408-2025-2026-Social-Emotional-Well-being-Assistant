const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
    cors: {
        origin: "*",
    },
});

const PORT = process.env.PORT || 3000;

app.get("/health", (req, res) => {
    res.status(200).json({ ok: true });
});

const logToRailway = (message) => {
    console.log(message); // Logs to Railway
};

io.on("connection", (socket) => {
    logToRailway(`[CONNECT] (${socket.id})`);

    // Join room
    socket.on("join-room", ({ room, username }) => {
        const prevRoom = socket.data.room;

        if (prevRoom && prevRoom !== room) {
            socket.leave(prevRoom);
            socket.to(prevRoom).emit("system-message", {
                message: `${socket.data.username ?? username} left ${prevRoom}`,
            });
            logToRailway(`[SWITCH] ${socket.data.username ?? username} left ${prevRoom}`);
        }

        socket.join(room);
        socket.data.username = username;
        socket.data.room = room;

        logToRailway(`[JOIN] ${username} joined ${room}`);

        socket.to(room).emit("system-message", {
            message: `${username} joined ${room}`,
        });
    });

    // Receive and broadcast messages
    socket.on("send-message", (message) => {
        const { room, username } = socket.data;
        if (!room) {
            logToRailway(`[ERROR] User ${username ?? "<unknown>"} tried to send message without joining a room.`);
            return;
        }

        if (!socket.rooms.has(room)) {
            logToRailway(`[ERROR] User ${username ?? "<unknown>"} tried to send message to ${room} without being in that room.`);
            return;
        }

        io.to(room).emit("new-message", {
            room,
            username,
            message,
            timestamp: new Date().toISOString(),
        });
    });

    // Leave room
    socket.on("leave-room", () => {
        const { room, username } = socket.data;
        if (!room) {
            logToRailway(`[ERROR] User ${username ?? "<unknown>"} tried to leave room without joining one.`);
            return;
        }

        socket.leave(room);
        socket.to(room).emit("system-message", {
            message: `${username} left ${room}`
        });
        logToRailway(`[LEAVE] ${username} left ${room}`);

        socket.data.room = null;
    });

    // Disconnect
    socket.on("disconnect", () => {
        const { username } = socket.data;
        logToRailway(`[DISCONNECT] ${username ?? "<unknown>"} (${socket.id})`);
    });
});

server.listen(PORT, () => {
    console.log(`Socket.IO server running on port ${PORT}`);
});