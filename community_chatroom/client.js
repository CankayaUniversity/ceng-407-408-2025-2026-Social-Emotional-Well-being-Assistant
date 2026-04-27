const { io } = require("socket.io-client");
const readline = require("readline");

const DEFAULT_SERVER_URL = "http://localhost:4000";

const serverUrl =
    process.argv[2] ||
    process.env.SERVER_URL ||
    DEFAULT_SERVER_URL;

const socket = io(serverUrl);

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
});

const username = `anon_${Math.floor(Math.random() * 10000)}`;
const userId = Math.floor(Math.random() * 1000000) + 1;

let currentRoom = null;

socket.on("connect", () => {
    console.log(`Connected as ${username}`);
    console.log(`Server: ${serverUrl}`);

    rl.question("Enter room name: ", (room) => {
        currentRoom = room;

        socket.emit("join-room", {
            room,
            username,
            userId,
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
    const sender = data.username ?? data.user ?? "<user>";
    const message = data.message ?? data.text ?? "";
    console.log(`[${room}] ${sender}: ${message}`);
});

socket.on("private-chat-invitation", ({ requesterId, requesterUsername }) => {
    rl.question(
        `[SYSTEM] ${requesterUsername} wants to start a private chat with you. Accept? (yes/no): `,
        (answer) => {
            if (answer.toLowerCase() === "yes") {
                socket.emit("private-chat-accept", { requesterId });
            } else {
                // Optionally, notify the requester that the invitation was declined.
                console.log("You declined the private chat request.");
            }
        }
    );
});

socket.on("private-chat-started", ({ room, participants }) => {
    console.log(`[SYSTEM] Private chat started in room: ${room}`);
    console.log(`[SYSTEM] Participants: ${participants.join(", ")}`);
    currentRoom = room; // Switch to the private room
});

rl.on("line", (input) => {
    if (input.startsWith("/private ")) {
        const targetUsername = input.slice("/private ".length).trim();
        // This is a simplified way to initiate a private chat.
        // In a real app, you'd need a way to get the socket ID of the target user.
        // For this example, we'll assume we can get it somehow.
        // This is a placeholder for a more robust user discovery mechanism.
        console.log(`Requesting private chat with ${targetUsername}... (dev-only feature)`);
        // You would need to get the targetSocketId from the server based on the username
        // For now, this is a conceptual implementation.
        // socket.emit("private-chat-request", { targetSocketId: "some_socket_id" });
        return;
    }

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
        socket.emit("join-room", { room, username, userId });
        console.log(`Joined room: ${room}`);
        return;
    }

    if (!currentRoom) {
        console.log("Not in a room. Use /join <room> (or /quit).");
        return;
    }

    socket.emit("send-message", input);
});