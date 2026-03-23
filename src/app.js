require("dotenv").config();
const express = require("express");
const cors = require("cors");

const prisma = require("./prisma");
const apiRoutes = require("../routes");

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
  res.send("API is running ✅  Use /health or /api/auth/register");
});

app.get("/health", (req, res) => {
  res.json({ ok: true, message: "Server is running" });
});

/* =======================
   API Routes
======================= */

app.use("/api", apiRoutes);

/* =======================
   Community cleanup job
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
  res.status(404).json({ message: "Route not found" });
});

module.exports = app;