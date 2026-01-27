require("dotenv").config();
const express = require("express");
const cors = require("cors");

const apiRoutes = require("../routes"); // routes/index.js

const app = express();

/* =======================
   Middlewares
======================= */
app.use(cors());
app.use(express.json());

/* =======================
   Root & Health
======================= */

// root (tarayıcıda localhost:3000 açınca Cannot GET / olmasın diye)
app.get("/", (req, res) => {
  res.send("API is running ✅  Use /health or /api/auth/register");
});

// health check
app.get("/health", (req, res) => {
  res.json({ ok: true, message: "Server is running" });
});

/* =======================
   API Routes
======================= */

// tüm api endpointleri /api altında
app.use("/api", apiRoutes);

/* =======================
   404 fallback (opsiyonel ama iyi)
======================= */
app.use((req, res) => {
  res.status(404).json({ message: "Route not found" });
});

module.exports = app;
