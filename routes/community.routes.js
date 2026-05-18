const express = require("express");
const communityController = require("../controllers/community.controller");
const auth = require("../middlewares/auth.middleware");

const router = express.Router();

router.get("/rooms", communityController.getOpenRooms);
router.get("/joined", auth, communityController.getJoinedCommunityRooms);
router.post("/join", auth, communityController.joinCommunityRoom);
router.post("/messages", auth, communityController.createMessage);
router.get("/messages", auth, communityController.getRoomMessages);
router.post("/leave", auth, communityController.leaveCommunityRoom);
router.delete("/messages/cleanup", communityController.cleanupOldMessages);

module.exports = router;