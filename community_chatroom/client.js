const { io } = require("socket.io-client");

const socket = io("http://localhost:3000");

const ROOM_ID = "community-room-1";

socket.on("connect", () => {
  console.log("Connected as client:", socket.id);

  socket.emit("join-room", ROOM_ID);

  setInterval(() => {
    socket.emit("send-message", {
      roomId: ROOM_ID,
      message: "Hello!"
    });
  }, 5000);
});

socket.on("new-message", (data) => {
  console.log(`[CHAT] ${data.user}: ${data.text}`);
});

socket.on("system-message", (data) => {
  console.log(`[SYSTEM] ${data.text}`);
});