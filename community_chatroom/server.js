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

io.on("connection", (socket) => {
    // Assign anonymous username todo: choose custom
    socket.username = `anon_${Math.floor(Math.random() * 10000)}`;

    console.log(`[CONNECT] ${socket.username} (${socket.id})`);

    // Join room
    socket.on("join-room", (roomId) => {
        socket.join(roomId);
        console.log(`[JOIN] ${socket.username} joined ${roomId}`);

        io.to(roomId).emit("system-message", {
            text: `${socket.username} joined the room`,
        });
    });

    // Receive and broadcast messages
    socket.on("send-message", ({ roomId, message }) => {
        console.log(`[MESSAGE] ${socket.username} -> ${roomId}: ${message}`);

        io.to(roomId).emit("new-message", {
            user: socket.username,
            text: message,
            timestamp: new Date().toISOString(),
        });
    });

    // Disconnect
    socket.on("disconnect", () => {
        console.log(`[DISCONNECT] ${socket.username}`);
    });
});

server.listen(PORT, () => {
    console.log(`Socket.IO server running on port ${PORT}`);
});
