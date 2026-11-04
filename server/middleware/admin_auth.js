const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { db } = require('../db');

const JWT_SECRET = process.env.ADMIN_JWT_SECRET || process.env.JWT_SECRET;
if (!JWT_SECRET) throw new Error('JWT_SECRET or ADMIN_JWT_SECRET must be set in environment');
const TOKEN_EXPIRY = '12h';

function adminAuth(req, res, next) {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: '请先登录管理后台' });
  }

  const token = authHeader.slice(7);
  let decoded;
  try {
    decoded = jwt.verify(token, JWT_SECRET);
  } catch (_) {
    return res.status(401).json({ message: '登录已过期，请重新登录' });
  }

  // Check blacklist
  const hash = crypto.createHash('sha256').update(token).digest('hex');
  const blacklisted = db.prepare(
    'SELECT id FROM admin_token_blacklist WHERE token_hash = ? AND expired_at > datetime(\'now\')'
  ).get(hash);
  if (blacklisted) {
    return res.status(401).json({ message: '登录已失效，请重新登录' });
  }

  // 管理员 token 必须带 role=admin 且账号仍在 admin_users 里。
  // 没配 ADMIN_JWT_SECRET 时两种 token 同一把钥匙签，不查身份的话普通用户 token 也能进后台
  if (decoded.role !== 'admin' || !decoded.id ||
      !db.prepare('SELECT id FROM admin_users WHERE id = ?').get(decoded.id)) {
    return res.status(403).json({ message: '没有管理权限' });
  }

  req.adminId = decoded.id;
  req.adminUsername = decoded.username;
  next();
}

module.exports = { adminAuth, JWT_SECRET, TOKEN_EXPIRY };
