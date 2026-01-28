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
    console.log(`[CONNECT] ${socket.username} (${socket.id})`);

    // Join room
    socket.on("join-room", ({room, username}) => {
        socket.join(room);
        socket.data.username = username;
        socket.data.room = room;

        console.log(`[JOIN] ${username} joined ${room}`);

        socket.to(room).emit("system-message", {
        message: `${username} joined ${room}`
        });
    });

    // Receive and broadcast messages
    socket.on("send-message", (message) => {   
        const {room, username} = socket.data;
        if(!room){
            console.error(`[ERROR] User ${username} tried to send message without joining a room.`);
            return;
        }

        io.to(room).emit("new-message", {
            user: username,
            text: message,
            timestamp: new Date().toISOString(),
        });
    });

    // Leave room
    socket.on("leave-room", () => {
        const {room, username} = socket.data;
        if(!room){
            console.error(`[ERROR] User ${username} tried to leave room without joining one.`);
            return;
        }

        socket.leave(room);
        socket.to(room).emit("system-message", {
            message: `${username} left ${room}`
        });
        console.log(`[LEAVE] ${username} left ${room}`);
    });

    // Disconnect
    socket.on("disconnect", () => {
        console.log(`[DISCONNECT] ${socket.username}`);
    });
});

server.listen(PORT, () => {
    console.log(`Socket.IO server running on port ${PORT}`);
});