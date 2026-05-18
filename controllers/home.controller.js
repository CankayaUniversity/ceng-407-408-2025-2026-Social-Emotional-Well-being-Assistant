// controllers/home.controller.js
const prisma = require("../src/prisma");

// --------------------
// Emergency Contacts
// --------------------
exports.listEmergencyContacts = async (req, res) => {
  try {
    const userId = req.user.id;

    const list = await prisma.emergencyContact.findMany({
      where: { userId },
      orderBy: [{ isPrimary: "desc" }, { createdAt: "desc" }],
    });

    return res.json(list);
  } catch (err) {
    console.error("listEmergencyContacts error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

exports.addEmergencyContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const { name, phone, relation, isPrimary } = req.body;

    if (!name || typeof name !== "string") {
      return res.status(400).json({ message: "name zorunlu" });
    }

    // Eğer yeni kayıt primary ise, önce diğerlerini false yap
    if (isPrimary === true) {
      await prisma.emergencyContact.updateMany({
        where: { userId, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    const created = await prisma.emergencyContact.create({
      data: {
        userId,
        name,
        phone: phone ?? null,
        relation: relation ?? null,
        isPrimary: isPrimary === true,
      },
    });

    return res.status(201).json(created);
  } catch (err) {
    console.error("addEmergencyContact error:", err);

    // unique(phone) çakışması olabilir
    if (err.code === "P2002") {
      return res.status(409).json({ message: "Bu telefon zaten kayıtlı olabilir." });
    }

    return res.status(500).json({ message: "Server error" });
  }
};

exports.updateEmergencyContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const id = Number(req.params.id);
    const { name, phone, relation, isPrimary } = req.body;

    if (!Number.isFinite(id)) {
      return res.status(400).json({ message: "Geçersiz id" });
    }

    // kayıt bu kullanıcıya mı ait?
    const existing = await prisma.emergencyContact.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      return res.status(404).json({ message: "Kayıt bulunamadı" });
    }

    if (isPrimary === true) {
      await prisma.emergencyContact.updateMany({
        where: { userId, isPrimary: true },
        data: { isPrimary: false },
      });
    }

    const updated = await prisma.emergencyContact.update({
      where: { id },
      data: {
        name: name ?? existing.name,
        phone: phone ?? existing.phone,
        relation: relation ?? existing.relation,
        isPrimary: isPrimary === true ? true : existing.isPrimary,
      },
    });

    return res.json(updated);
  } catch (err) {
    console.error("updateEmergencyContact error:", err);

    if (err.code === "P2002") {
      return res.status(409).json({ message: "Bu telefon zaten kayıtlı olabilir." });
    }

    return res.status(500).json({ message: "Server error" });
  }
};

exports.deleteEmergencyContact = async (req, res) => {
  try {
    const userId = req.user.id;
    const id = Number(req.params.id);

    if (!Number.isFinite(id)) {
      return res.status(400).json({ message: "Geçersiz id" });
    }

    const existing = await prisma.emergencyContact.findFirst({
      where: { id, userId },
    });

    if (!existing) {
      return res.status(404).json({ message: "Kayıt bulunamadı" });
    }

    await prisma.emergencyContact.delete({ where: { id } });
    return res.json({ message: "Silindi" });
  } catch (err) {
    console.error("deleteEmergencyContact error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// --------------------
// Moods
// --------------------

// GET /api/home/moods?month=YYYY-MM
exports.getMoodsByMonth = async (req, res) => {
  try {
    const userId = req.user.id;
    const month = req.query.month; // "2026-01"

    if (!month || typeof month !== "string" || !/^\d{4}-\d{2}$/.test(month)) {
      return res.status(400).json({ message: "month formatı YYYY-MM olmalı" });
    }

    const [y, m] = month.split("-").map(Number);
    const start = new Date(Date.UTC(y, m - 1, 1));
    const end = new Date(Date.UTC(y, m, 1)); // sonraki ayın 1'i

    const entries = await prisma.moodEntry.findMany({
      where: {
        userId,
        entryDate: { gte: start, lt: end },
      },
      orderBy: { entryDate: "asc" },
    });

    return res.json(entries);
  } catch (err) {
    console.error("getMoodsByMonth error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};

// POST /api/home/moods  body: { entryDate: "2026-01-27", mood: 4, note?: "..." }
exports.upsertMoodEntry = async (req, res) => {
  try {
    const userId = req.user.id;
    const { entryDate, mood, note } = req.body;

    if (!entryDate || typeof entryDate !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(entryDate)) {
      return res.status(400).json({ message: "entryDate formatı YYYY-MM-DD olmalı" });
    }

    const moodInt = Number(mood);
    if (!Number.isInteger(moodInt) || moodInt < 1 || moodInt > 5) {
      return res.status(400).json({ message: "mood 1-5 arası olmalı" });
    }

    // DATE alanı kullandığımız için saat kısmı önemli olmasın diye UTC 00:00 yapıyoruz
    const [yy, mm, dd] = entryDate.split("-").map(Number);
    const date = new Date(Date.UTC(yy, mm - 1, dd));

    // UNIQUE(userId, entryDate) var -> önce var mı bak, sonra update/create
    const existing = await prisma.moodEntry.findFirst({
      where: { userId, entryDate: date },
    });

    let result;
    if (existing) {
      result = await prisma.moodEntry.update({
        where: { id: existing.id },
        data: { mood: moodInt, note: note ?? null },
      });
    } else {
      result = await prisma.moodEntry.create({
        data: { userId, entryDate: date, mood: moodInt, note: note ?? null },
      });
    }

    return res.json(result);
  } catch (err) {
    console.error("upsertMoodEntry error:", err);
    return res.status(500).json({ message: "Server error" });
  }
};
