require("dotenv").config();

const express = require("express");
const cors = require("cors");
const cron = require("node-cron");

const prisma = require("./prisma");
const apiRoutes = require("../routes");
const eventsController = require("../controllers/events.controller");

const app = express();

/* =======================
   Middlewares
======================= */
app.use(cors());
app.use(express.json());

/* =======================
   Root & Health
======================= */
app.get("/", (req, res) => {
  res.send("API is running ✅ Use /health or /api/auth/register");
});

app.get("/health", (req, res) => {
  res.json({
    ok: true,
    message: "Server is running",
  });
});

/* =======================
   API Routes
======================= */
app.use("/api", apiRoutes);

/* =======================
   Scheduled Jobs
======================= */

// 1. Event Synchronization (Every 24 hours at midnight)
cron.schedule("0 0 * * *", () => {
  eventsController.syncEventsFromSource();
});

// Sync on startup in the background to ensure fresh data after deployment
(async () => {
  console.log("Running event sync on startup...");
  // Runs in the background so it doesn't block the server from starting
  eventsController.syncEventsFromSource();
})();

/* 2. Community cleanup job
24 saatten eski mesajları siler
======================= */
setInterval(async () => {
  try {
    const cutoffDate = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const result = await prisma.communityMessage.deleteMany({
      where: {
        createdAt: {
          lt: cutoffDate,
        },
      },
    });

    if (result.count > 0) {
      console.log(`🧹 Deleted ${result.count} old community messages`);
    }
  } catch (error) {
    console.error("cleanup job error:", error.message);
  }
}, 10 * 60 * 1000);

/* =======================
   404 fallback
======================= */
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: "Route not found",
  });
});

module.exports = app;