const express = require("express");
const authRoutes = require("./auth.routes");
const homeRoutes = require("./home.routes");
const communityRoutes = require("./community.routes");

const authMiddleware = require("../middlewares/auth.middleware");
const authService = require("../services/auth.service");

const router = express.Router();

router.use("/auth", authRoutes);
router.use("/home", homeRoutes);
router.use("/community", communityRoutes);

// örnek protected endpoint: login olmadan girilmez
router.get("/me", authMiddleware, async (req, res) => {
  const user = await authService.findUserById(req.user.id);
  return res.json({ user });
});

module.exports = router;