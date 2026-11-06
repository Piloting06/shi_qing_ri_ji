const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { db } = require('../db');
const auth = require('../middleware/auth');
const { sendSms } = require('../sms');
const { sendEmailCode } = require('../mail');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
const router = express.Router();

// 验证码只存 HMAC（服务端密钥 + 目标 + 码）：库泄露也没法离线穷举出六位码
const codeHash = (target, code) =>
  crypto.createHmac('sha256', process.env.JWT_SECRET || '').update(`${target}:${String(code || '')}`).digest('hex');
// 邮箱统一小写，A@x.com 与 a@x.com 是同一个
const normEmail = (v) => String(v || '').trim().toLowerCase();
// IP 层只挡批量滥用，放宽到 30 次 / 10 分钟：校园网、运营商 NAT 下很多人共用一个公网 IP。
// 防轰炸主要靠下面按「号码 / 邮箱」的限制：一分钟 1 次、一天 10 次。
const sendLimiter = rateLimit({ windowMs: 10 * 60e3, max: 30, standardHeaders: true, legacyHeaders: false, message: { message: '验证码发得太频繁了，过十分钟再试' } });
const verifyLimiter = rateLimit({ windowMs: 10 * 60e3, max: 60, standardHeaders: true, legacyHeaders: false, message: { message: '试得太多了，过十分钟再来' } });
// 有效期 5 分钟：过期时间还剩 4 分钟以上 = 一分钟内刚发过；过期时间在 24 小时内 = 今天发过
const sentWithinMinute = (target) =>
  db.prepare("SELECT id FROM sms_codes WHERE phone = ? AND expires_at > datetime('now', '+4 minutes')").get(target);
const sentToday = (target) =>
  db.prepare("SELECT COUNT(*) AS n FROM sms_codes WHERE phone = ? AND expires_at > datetime('now', '-1435 minutes')").get(target).n;
const MAX_ATTEMPTS = 5;
/** 校验验证码：只认最新一条有效码；错一次记一次，错满 5 次作废（换 IP 也猜不下去） */
function checkCode(target, code) {
  const row = db.prepare(
    "SELECT id, code, attempts FROM sms_codes WHERE phone = ? AND expires_at > datetime('now') AND used = 0 ORDER BY id DESC LIMIT 1"
  ).get(target);
  if (!row) return null;
  if (row.code === codeHash(target, code)) return row;
  const attempts = Number(row.attempts || 0) + 1;
  db.prepare('UPDATE sms_codes SET attempts = ?, used = CASE WHEN ? >= ? THEN 1 ELSE used END WHERE id = ?')
    .run(attempts, attempts, MAX_ATTEMPTS, row.id);
  return null;
}
function tooManySends(target, res) {
  if (sentWithinMinute(target)) {
    res.status(429).json({ message: '一分钟内只能发一次' });
    return true;
  }
  if (sentToday(target) >= 10) {
    res.status(429).json({ message: '今天发得太多了，明天再试' });
    return true;
  }
  return false;
}

router.post('/register', (req, res) => {
  try {
    const { password, security_question_type, security_question, security_answer } = req.body;
    const phone = String(req.body.phone || '').trim();
    if (!/^1\d{10}$/.test(phone) || !password) {
      return res.status(400).json({ message: '请输入正确的手机号' });
    }
    if (password.length < 6) {
      return res.status(400).json({ message: '密码至少6位' });
    }
    const existing = db.prepare('SELECT id, is_active FROM users WHERE phone = ?').get(phone);
    if (existing && Number(existing.is_active) === 1) {
      return res.status(409).json({ message: '该手机号已注册' });
    }
    if (existing) {
      db.prepare('UPDATE users SET phone = ?, is_active = 0, deleted_at = COALESCE(deleted_at, datetime(\'now\')) WHERE id = ?')
        .run(`deleted_${existing.id}_${Date.now()}_${phone}`, existing.id);
    }
    const hash = bcrypt.hashSync(password, 10);
    let answerHash = null;
    if (security_answer) {
      answerHash = bcrypt.hashSync(security_answer, 10);
    }
    const result = db.prepare(
      'INSERT INTO users (phone, username, password_hash, security_question_type, security_question, security_answer_hash) VALUES (?, ?, ?, ?, ?, ?)'
    ).run(phone, '用户' + phone.slice(-4), hash, security_question_type || null, security_question || null, answerHash);
    const token = jwt.sign({ userId: result.lastInsertRowid }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, display_name: '用户' + phone.slice(-4) });
  } catch (e) {
    console.error('register:', e.message);
    res.status(500).json({ message: '注册失败' });
  }
});

router.post('/login', (req, res) => {
  try {
    const phone = String(req.body.phone || '').trim();
    const { password } = req.body;
    const user = db.prepare('SELECT * FROM users WHERE phone = ? AND is_active = 1 AND deleted_at IS NULL').get(phone);
    if (!user) return res.status(401).json({ message: '账号不存在' });
    if (!bcrypt.compareSync(password, user.password_hash)) {
      return res.status(401).json({ message: '密码错误' });
    }
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, display_name: user.username });
  } catch (e) {
    console.error('login:', e.message);
    res.status(500).json({ message: '登录失败' });
  }
});

router.post('/change-password', auth, (req, res) => {
  try {
    const { old_password, new_password } = req.body;
    const user = db.prepare('SELECT password_hash FROM users WHERE id = ?').get(req.userId);
    if (!bcrypt.compareSync(old_password, user.password_hash)) {
      return res.status(400).json({ message: '当前密码错误' });
    }
    const hash = bcrypt.hashSync(new_password, 10);
    db.prepare('UPDATE users SET password_hash = ? WHERE id = ?').run(hash, req.userId);
    res.json({ message: '密码已更改' });
  } catch (e) {
    res.status(500).json({ message: '修改失败' });
  }
});

router.post('/change-username', auth, (req, res) => {
  try {
    const { username } = req.body;
    if (!username || !String(username).trim()) {
      return res.status(400).json({ message: '名字不能为空' });
    }
    if (String(username).trim().length > 20) {
      return res.status(400).json({ message: '名字最多 20 个字' });
    }
    db.prepare('UPDATE users SET username = ? WHERE id = ?').run(String(username).trim(), req.userId);
    res.json({ message: '名字已更新' });
  } catch (e) {
    res.status(500).json({ message: '修改失败' });
  }
});

router.post('/delete-account', auth, (req, res) => {
  try {
    const user = db.prepare('SELECT id, phone FROM users WHERE id = ? AND is_active = 1').get(req.userId);
    if (!user) return res.status(404).json({ message: '账号不存在或已注销' });

    const releasedPhone = `deleted_${user.id}_${Date.now()}_${user.phone}`;
    db.prepare('UPDATE users SET phone = ?, is_active = 0, deleted_at = datetime(\'now\') WHERE id = ?')
      .run(releasedPhone, req.userId);
    db.prepare('DELETE FROM friendships WHERE (user_id = ? OR friend_id = ?) AND status IN (0, 1)')
      .run(req.userId, req.userId);
    res.json({ message: '账号已注销' });
  } catch (e) {
    res.status(500).json({ message: '注销失败' });
  }
});

// ── SMS & password reset ──

router.post('/send-sms-code', sendLimiter, async (req, res) => {
  try {
    const phone = String(req.body.phone || '').trim();
    if (!/^1[3-9]\d{9}$/.test(phone)) {
      return res.status(400).json({ message: '手机号格式错误' });
    }
    if (tooManySends(phone, res)) return;
    const code = String(crypto.randomInt(100000, 1000000));
    try {
      await sendSms(phone, code);
    } catch (e) {
      // 发不出去就如实说，不再回「已发送」让人干等
      console.error('SMS send error:', e.message);
      return res.status(502).json({ message: '验证码没发出去，稍后再试' });
    }
    db.prepare('INSERT INTO sms_codes (phone, code, expires_at) VALUES (?, ?, datetime(\'now\', \'+5 minutes\'))')
      .run(phone, codeHash(phone, code));
    res.json({ message: '验证码已发送' });
  } catch (e) {
    console.error('send-sms-code:', e.message);
    res.status(500).json({ message: '发送失败' });
  }
});

router.post('/reset-password', verifyLimiter, (req, res) => {
  try {
    const phone = String(req.body.phone || '').trim();
    const { code, new_password } = req.body;
    if (!new_password || new_password.length < 6) {
      return res.status(400).json({ message: '密码至少6位' });
    }
    const row = checkCode(phone, code);
    if (!row) {
      return res.status(400).json({ message: '验证码错误或已过期' });
    }
    const hash = bcrypt.hashSync(new_password, 10);
    db.prepare('UPDATE users SET password_hash = ? WHERE phone = ? AND is_active = 1').run(hash, phone);
    db.prepare('UPDATE sms_codes SET used = 1 WHERE id = ?').run(row.id);
    res.json({ message: '密码已重置' });
  } catch (e) {
    console.error('reset-password:', e.message);
    res.status(500).json({ message: '重置失败' });
  }
});

// ── Email auth ──

router.post('/send-email-code', sendLimiter, async (req, res) => {
  try {
    const email = normEmail(req.body.email);
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) || email.length > 120) {
      return res.status(400).json({ message: '邮箱格式错误' });
    }
    if (tooManySends(email, res)) return;
    const code = String(crypto.randomInt(100000, 1000000));
    try {
      await sendEmailCode(email, code);
    } catch (e) {
      console.error('Email send error:', e.message);
      return res.status(502).json({ message: '验证码没发出去，稍后再试' });
    }
    db.prepare("INSERT INTO sms_codes (phone, code, expires_at) VALUES (?, ?, datetime('now', '+5 minutes'))")
      .run(email, codeHash(email, code));
    res.json({ message: '验证码已发送' });
  } catch (e) {
    console.error('send-email-code:', e.message);
    res.status(500).json({ message: '发送失败' });
  }
});

router.post('/email-register', verifyLimiter, (req, res) => {
  try {
    const email = normEmail(req.body.email);
    const { password, code } = req.body;
    if (!email.includes('@') || !password || password.length < 6) {
      return res.status(400).json({ message: '请填写完整信息' });
    }
    const vRow = checkCode(email, code);
    if (!vRow) return res.status(400).json({ message: '验证码错误或已过期' });
    db.prepare('UPDATE sms_codes SET used = 1 WHERE id = ?').run(vRow.id);
    const existing = db.prepare('SELECT id FROM users WHERE lower(email) = ? AND is_active = 1').get(email);
    if (existing) return res.status(409).json({ message: '该邮箱已注册' });
    const hash = bcrypt.hashSync(password, 10);
    const username = email.split('@')[0];
    const result = db.prepare('INSERT INTO users (phone, username, password_hash, email) VALUES (?, ?, ?, ?)')
      .run(email, username, hash, email);
    const token = jwt.sign({ userId: result.lastInsertRowid }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, display_name: username });
  } catch (e) {
    console.error('email-register:', e.message);
    res.status(500).json({ message: '注册失败' });
  }
});

router.post('/email-login', (req, res) => {
  try {
    const email = normEmail(req.body.email);
    const { password } = req.body;
    const user = db.prepare('SELECT * FROM users WHERE lower(email) = ? AND is_active = 1 AND deleted_at IS NULL').get(email);
    if (!user || !bcrypt.compareSync(password, user.password_hash)) {
      return res.status(401).json({ message: '邮箱或密码错误' });
    }
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({ token, display_name: user.username });
  } catch (e) {
    console.error('email-login:', e.message);
    res.status(500).json({ message: '登录失败' });
  }
});

router.post('/bind-email', auth, verifyLimiter, (req, res) => {
  try {
    const email = normEmail(req.body.email);
    const code = req.body.code;
    if (!email.includes('@')) return res.status(400).json({ message: '邮箱格式错误' });
    const vRow = checkCode(email, code);
    if (!vRow) return res.status(400).json({ message: '验证码错误或已过期' });
    db.prepare('UPDATE sms_codes SET used = 1 WHERE id = ?').run(vRow.id);
    const dup = db.prepare('SELECT id FROM users WHERE lower(email) = ? AND id != ? AND is_active = 1').get(email, req.userId);
    if (dup) return res.status(409).json({ message: '该邮箱已被其他账号绑定' });
    db.prepare('UPDATE users SET email = ? WHERE id = ?').run(email, req.userId);
    res.json({ message: '邮箱绑定成功', email });
  } catch (e) {
    console.error('bind-email:', e.message);
    res.status(500).json({ message: '绑定失败' });
  }
});

router.get('/profile', auth, (req, res) => {
  try {
    const user = db.prepare('SELECT phone, email, username FROM users WHERE id = ?').get(req.userId);
    if (!user) return res.status(404).json({ message: '用户不存在' });
    res.json({ phone: user.phone, email: user.email, display_name: user.username });
  } catch (e) {
    res.status(500).json({ message: '获取失败' });
  }
});

module.exports = router;
