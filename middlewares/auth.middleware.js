const { verifyToken } = require("../utils/jwt");

function authMiddleware(req, res, next) {
  const header = req.headers.authorization; // "Bearer <token>"
  if (!header) return res.status(401).json({ message: "Authorization header yok" });

  const [type, token] = header.split(" ");
  if (type !== "Bearer" || !token) {
    return res.status(401).json({ message: "Token formatı hatalı (Bearer <token>)" });
  }

  try {
    const payload = verifyToken(token);
    req.user = payload; // { id, email }
    next();
  } catch (err) {
    return res.status(401).json({ message: "Token geçersiz/expired" });
  }
}

module.exports = authMiddleware;
