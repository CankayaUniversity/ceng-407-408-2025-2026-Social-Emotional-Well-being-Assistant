const { io } = require("socket.io-client");
const readline = require("readline");

const socket = io("http://localhost:3000");

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

const username = `anon_${Math.floor(Math.random() * 10000)}`;

let currentRoom = null;

socket.on("connect", () => {
    console.log(`Connected as ${username}`);

    rl.question("Enter room name: ", (room) => {
        currentRoom = room;

        socket.emit("join-room", {
            room,
            username,
        });

        console.log(`Joined room: ${room}`);
        console.log("Type messages and press Enter\n");
    });
});

socket.on("system-message", (data) => {
    console.log(`[SYSTEM] ${data.message}`);
});

socket.on("new-message", (data) => {
    const room = data.room ?? currentRoom ?? "<room>";
    const username = data.username ?? data.user ?? "<user>";
    const message = data.message ?? data.text ?? "";
    console.log(`[${room}] ${username}: ${message}`);
});

// Leave, exit or rejoin
rl.on("line", (input) => {
    if (input === "/leave") {
        socket.emit("leave-room");
        console.log("Left room");
        currentRoom = null;
        return;
    }

    if (input === "/quit" || input === "/exit") {
        console.log("Goodbye");
        socket.disconnect();
        rl.close();
        process.exit(0);
    }

    if (input.startsWith("/join ")) {
        const room = input.slice("/join ".length).trim();
        if (!room) {
            console.log("Usage: /join <room>");
            return;
        }

        currentRoom = room;
        socket.emit("join-room", { room, username });
        console.log(`Joined room: ${room}`);
        return;
    }

    if (!currentRoom) {
        console.log("Not in a room. Use /join <room> (or /quit). ");
        return;
    }

    socket.emit("send-message", input);
});
