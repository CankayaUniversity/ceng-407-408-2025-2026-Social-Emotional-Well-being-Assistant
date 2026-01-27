// routes/home.routes.js
const express = require("express");
const auth = require("../middlewares/auth.middleware");
const homeController = require("../controllers/home.controller");

const router = express.Router();

// Preferences
router.get("/preferences", auth, homeController.getPreferences);
router.put("/preferences", auth, homeController.updatePreferences);

// Emergency Contacts
router.get("/emergency-contacts", auth, homeController.listEmergencyContacts);
router.post("/emergency-contacts", auth, homeController.addEmergencyContact);
router.put("/emergency-contacts/:id", auth, homeController.updateEmergencyContact);
router.delete("/emergency-contacts/:id", auth, homeController.deleteEmergencyContact);

// Moods
router.get("/moods", auth, homeController.getMoodsByMonth);
router.post("/moods", auth, homeController.upsertMoodEntry);

module.exports = router;