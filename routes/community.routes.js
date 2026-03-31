const express = require("express");
const communityController = require("../controllers/community.controller");

const router = express.Router();

router.get("/rooms", communityController.getOpenRooms);
router.post("/join", communityController.joinCommunityRoom);
router.post("/messages", communityController.createMessage);
router.get("/messages", communityController.getRoomMessages);
router.post("/leave", communityController.leaveCommunityRoom);
router.delete("/messages/cleanup", communityController.cleanupOldMessages);

module.exports = router;