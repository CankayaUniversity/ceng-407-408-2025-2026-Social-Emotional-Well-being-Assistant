const express = require("express");

const authRoutes = require("./auth.routes");
const homeRoutes = require("./home.routes");
const communityRoutes = require("./community.routes");
const eventsRoutes = require("./events.routes");

const userController = require("../controllers/user.controller");
const authMiddleware = require("../middlewares/auth.middleware");
const authService = require("../services/auth.service");

const router = express.Router();

/* =======================
   Route Groups
======================= */
router.use("/auth", authRoutes);
router.use("/home", homeRoutes);
router.use("/community", communityRoutes);
router.use("/events", eventsRoutes);

router.get("/user/profile", authMiddleware, userController.getProfilePreferences);
router.put("/user/profile", authMiddleware, userController.updateProfile);

/* =======================
   Protected Example Route
======================= */
router.get("/me", authMiddleware, async (req, res) => {
  try {
    const user = await authService.findUserById(req.user.id);
    return res.status(200).json({ user });
  } catch (error) {
    console.error("GET /api/me error:", error);
    return res.status(500).json({
      success: false,
      error: "Kullanıcı bilgisi alınamadı.",
    });
  }
});

module.exports = router;