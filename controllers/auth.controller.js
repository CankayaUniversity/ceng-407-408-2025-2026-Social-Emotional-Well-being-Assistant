const { hashPassword, comparePassword } = require("../utils/hash");
const { signToken } = require("../utils/jwt");
const authService = require("../services/auth.service");

async function register(req, res) {
  // ✅ EN KRİTİK LOG: Frontend istek atıyor mu / body geliyor mu?
  console.log("✅ REGISTER HIT");
  console.log("➡️ URL:", req.originalUrl);
  console.log("➡️ Headers content-type:", req.headers["content-type"]);
  console.log("➡️ Body:", req.body);

  try {
    const { email, password, name } = req.body || {};

    // Body hiç gelmiyorsa / boşsa yakala
    if (!req.body || Object.keys(req.body).length === 0) {
      return res.status(400).json({
        message:
          "Body boş geldi. Frontend JSON göndermiyor olabilir veya express.json() yok.",
      });
    }

    if (!email || !password) {
      return res.status(400).json({ message: "email ve password zorunlu" });
    }

    const normalizedEmail = String(email).trim().toLowerCase();
    const normalizedName =
      name !== undefined && name !== null && String(name).trim() !== ""
        ? String(name).trim()
        : null;

    const exists = await authService.findUserByEmail(normalizedEmail);
    if (exists) {
      return res.status(409).json({ message: "Bu email zaten kayıtlı" });
    }

    const password_hash = await hashPassword(String(password));

    const user = await authService.createUser({
      email: normalizedEmail,
      password_hash,
      name: normalizedName,
    });

    return res.status(201).json({ message: "Kayıt başarılı", user });
  } catch (err) {
    console.error("❌ REGISTER ERROR FULL:", err);
    return res.status(500).json({
      message: "Sunucu hatası",
      error: err?.message || String(err),
      code: err?.code || null,
    });
  }
}

async function login(req, res) {
  // İstersen login debug da aç:
  // console.log("✅ LOGIN HIT", req.body);

  try {
    const { email, password } = req.body || {};

    if (!email || !password) {
      return res.status(400).json({ message: "email ve password zorunlu" });
    }

    const normalizedEmail = String(email).trim().toLowerCase();

    const user = await authService.findUserByEmail(normalizedEmail);
    if (!user) {
      return res.status(401).json({ message: "Email veya şifre yanlış" });
    }

    const ok = await comparePassword(String(password), user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: "Email veya şifre yanlış" });
    }

    const token = signToken({ id: user.id, email: user.email });

    return res.json({
      message: "Giriş başarılı",
      token,
      user: { id: user.id, email: user.email, name: user.name ?? null },
    });
  } catch (err) {
    console.error("❌ LOGIN ERROR FULL:", err);
    return res.status(500).json({
      message: "Sunucu hatası",
      error: err?.message || String(err),
      code: err?.code || null,
    });
  }
}

module.exports = { register, login };