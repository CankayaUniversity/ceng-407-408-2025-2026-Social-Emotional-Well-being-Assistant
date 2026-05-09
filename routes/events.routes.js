const express = require("express");
const router = express.Router();
const eventsController = require("../controllers/events.controller");

// This route can be public as it's just event info
router.get("/", eventsController.getUpcomingEvents);

module.exports = router;
