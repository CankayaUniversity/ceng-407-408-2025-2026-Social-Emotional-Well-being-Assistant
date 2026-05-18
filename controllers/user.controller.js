const prisma = require("../src/prisma");

const getProfilePreferences = async (req, res) => {
  try {
    const userId = Number(req.user?.id);
    const user = await prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });

    if (!user) {
      return res.status(404).json({ success: false, error: "Kullanıcı bulunamadı." });
    }

    let preferences = await prisma.userPreferences.findUnique({
      where: { userId },
    });

    if (!preferences) {
      const randomSuffix = Math.floor(1000 + Math.random() * 9000);
      preferences = await prisma.userPreferences.create({
        data: {
          userId,
          nickname: `Anonim${randomSuffix}`,
          isAnonymous: true,
        },
      });
    }

    return res.status(200).json({ success: true, preferences });
  } catch (error) {
    console.error("getProfilePreferences error:", error);
    return res.status(500).json({ success: false, error: "Profil tercihleri alınamadı." });
  }
};

const normalizeBoolean = (value) => {
  if (typeof value === "boolean") return value;
  if (typeof value === "string") {
    const normalized = value.trim().toLowerCase();
    return normalized === "true" || normalized === "1" || normalized === "yes";
  }
  if (typeof value === "number") return value === 1;
  return undefined;
};

const updateProfile = async (req, res) => {
  try {
    const userId = Number(req.user?.id); // JWT'den gelen ID
    const { nickname } = req.body;
    const anonymousMode = req.body.anonymous_mode ?? req.body.isAnonymous;
    const isAnonymous = normalizeBoolean(anonymousMode);

    const updateData = {};
    if (nickname !== undefined) {
      if (typeof nickname !== "string" || !nickname.trim()) {
        return res.status(400).json({ success: false, error: "nickname geçerli bir string olmalı." });
      }
      updateData.nickname = nickname.trim();
    }
    if (anonymousMode !== undefined) {
      updateData.isAnonymous = isAnonymous;
    }

    if (Object.keys(updateData).length === 0) {
      return res.status(400).json({ success: false, error: "Güncelleme için nickname veya anonymous_mode alanı gerekli." });
    }

    const preferences = await prisma.userPreferences.upsert({
      where: { userId: userId },
      update: updateData,
      create: {
        userId: userId,
        nickname: updateData.nickname ?? `Anonim${Math.floor(1000 + Math.random() * 9000)}`,
        isAnonymous: updateData.isAnonymous ?? true,
      },
    });

    return res.status(200).json({ success: true, preferences });
  } catch (error) {
    console.error("updateProfile error:", error);
    return res.status(500).json({ success: false, error: "Profil güncellenemedi." });
  }
};

module.exports = { getProfilePreferences, updateProfile };