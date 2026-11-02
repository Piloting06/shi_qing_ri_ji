const jwt = require('jsonwebtoken');
const { db } = require('../db');

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ message: '请先登录' });
  }
  try {
    const payload = jwt.verify(token, process.env.JWT_SECRET);
    const user = db.prepare('SELECT id FROM users WHERE id = ? AND is_active = 1 AND deleted_at IS NULL').get(payload.userId);
    if (!user) return res.status(401).json({ message: '登录已过期，请重新登录' });
    req.userId = payload.userId;
    next();
  } catch (_) {
    return res.status(401).json({ message: '登录已过期，请重新登录' });
  }
}

module.exports = authMiddleware;
