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
   404 fallback
======================= */
app.use((req, res) => {
  res.status(404).json({ message: "Route not found" });
});

module.exports = app;
