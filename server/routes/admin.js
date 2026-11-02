const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { db } = require('../db');
const { adminAuth, JWT_SECRET, TOKEN_EXPIRY } = require('../middleware/admin_auth');
const { invalidateCache } = require('../sensitive_words');
const router = express.Router();
const path = require('path');
const fs = require('fs');

// Serve admin panel HTML
const _adminHtml = fs.readFileSync(path.join(__dirname, '..', 'admin', 'index.html'), 'utf-8');
router.get('/panel', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.removeHeader('Content-Security-Policy');
  res.send(_adminHtml);
});

function logAction(adminId, action, targetType, targetId, detail) {
  try {
    db.prepare(
      'INSERT INTO admin_logs (admin_id, action, target_type, target_id, detail) VALUES (?,?,?,?,?)'
    ).run(adminId, action, targetType, targetId, detail);
  } catch (_) {}
}

// ── Login ──
router.post('/login', (req, res) => {
  try {
    const { username, password } = req.body;
    if (!username || !password) {
      return res.status(400).json({ message: '请输入账号和密码' });
    }
    const admin = db.prepare('SELECT id, username, password_hash FROM admin_users WHERE username = ?').get(username);
    if (!admin || !bcrypt.compareSync(password, admin.password_hash)) {
      return res.status(401).json({ message: '账号或密码错误' });
    }
    const token = jwt.sign({ id: admin.id, username: admin.username }, JWT_SECRET, { expiresIn: TOKEN_EXPIRY });
    res.json({ token, username: admin.username });
  } catch (e) { res.status(500).json({ message: '登录失败' }); }
});

// ── Logout ──
router.post('/logout', adminAuth, (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const token = authHeader.slice(7);
    const hash = crypto.createHash('sha256').update(token).digest('hex');
    db.prepare(
      "INSERT INTO admin_token_blacklist (token_hash, expired_at) VALUES (?, datetime('now', '+12 hours'))"
    ).run(hash);
    res.json({ message: '已退出' });
  } catch (e) { res.status(500).json({ message: '退出失败' }); }
});

// ── Dashboard stats ──
router.get('/dashboard', adminAuth, (req, res) => {
  try {
    const totalUsers = db.prepare('SELECT COUNT(*) as cnt FROM users WHERE is_active = 1 AND deleted_at IS NULL').get()?.cnt || 0;
    const today = new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10);
    const todayMs = Date.parse(`${today}T00:00:00+08:00`);
    const todayUtc = new Date(todayMs).toISOString().slice(0, 19).replace('T', ' ');
    const tomorrowUtc = new Date(todayMs + 86400000).toISOString().slice(0, 19).replace('T', ' ');
    const todayActive = db.prepare(
      'SELECT COUNT(DISTINCT user_id) as cnt FROM moods WHERE created_at >= ? AND created_at < ?'
    ).get(todayUtc, tomorrowUtc)?.cnt || 0;
    const totalMessages = db.prepare('SELECT COUNT(*) as cnt FROM treehole_messages').get()?.cnt || 0;
    const totalCapsules = db.prepare('SELECT COUNT(*) as cnt FROM time_capsules').get()?.cnt || 0;
    const totalComments = db.prepare('SELECT COUNT(*) as cnt FROM treehole_comments').get()?.cnt || 0;

    res.json({ totalUsers, todayActive, totalMessages, totalCapsules, totalComments });
  } catch (e) { res.status(500).json({ message: '获取数据失败' }); }
});

// ── Users list ──
router.get('/users', adminAuth, (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;
    const q = (req.query.q || '').trim();

    let sql = `SELECT id, phone, username, is_active, deleted_at, strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at FROM users`;
    let countSql = 'SELECT COUNT(*) as cnt FROM users';
    const params = [];
    const countParams = [];

    if (q) {
      const where = ' WHERE (phone LIKE ? OR username LIKE ?)';
      sql += where;
      countSql += where;
      params.push(`%${q}%`, `%${q}%`);
      countParams.push(`%${q}%`, `%${q}%`);
    }

    sql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const total = db.prepare(countSql).get(...countParams)?.cnt || 0;
    const users = db.prepare(sql).all(...params);

    res.json({ users, total, page, totalPages: Math.ceil(total / limit) || 1 });
  } catch (e) { res.status(500).json({ message: '获取用户列表失败' }); }
});

// ── User detail ──
router.get('/users/:id', adminAuth, (req, res) => {
  try {
    const user = db.prepare(
      'SELECT id, phone, username, is_active, deleted_at, strftime(\'%Y-%m-%dT%H:%M:%SZ\', created_at) AS created_at FROM users WHERE id = ?'
    ).get(req.params.id);
    if (!user) return res.status(404).json({ message: '用户不存在' });

    const moods = db.prepare('SELECT * FROM moods WHERE user_id = ? ORDER BY date DESC LIMIT 30').all(user.id);
    const capsules = db.prepare('SELECT * FROM time_capsules WHERE user_id = ? ORDER BY open_date DESC LIMIT 30').all(user.id);
    const checkins = db.prepare('SELECT * FROM checkins WHERE user_id = ? ORDER BY date DESC LIMIT 30').all(user.id);

    res.json({ user, moods, capsules, checkins });
  } catch (e) { res.status(500).json({ message: '获取用户详情失败' }); }
});

// ── Ban/unban user ──
router.post('/users/:id/ban', adminAuth, (req, res) => {
  try {
    const user = db.prepare('SELECT id, is_active FROM users WHERE id = ?').get(req.params.id);
    if (!user) return res.status(404).json({ message: '用户不存在' });

    const newStatus = user.is_active ? 0 : 1;
    if (newStatus === 0) {
      const garbledPhone = `banned_${user.id}_${Date.now()}`;
      db.prepare('UPDATE users SET phone = ?, is_active = 0, deleted_at = ? WHERE id = ?').run(
        garbledPhone, new Date().toISOString(), user.id
      );
    } else {
      db.prepare('UPDATE users SET is_active = ?, deleted_at = ? WHERE id = ?').run(newStatus, null, user.id);
    }
    logAction(req.adminId, newStatus ? 'unban_user' : 'ban_user', 'user', user.id, `Set is_active=${newStatus}`);
    res.json({ message: newStatus ? '已解封' : '已封禁', is_active: newStatus });
  } catch (e) { res.status(500).json({ message: '操作失败' }); }
});

// ── Treehole messages list ──
router.get('/treehole', adminAuth, (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;
    const q = (req.query.q || '').trim();

    let sql = `SELECT m.id, m.content, m.user_id, u.phone, m.cloud_hugs, m.cloud_coffees, m.is_visible,
               strftime('%Y-%m-%dT%H:%M:%SZ', m.created_at) AS created_at
               FROM treehole_messages m LEFT JOIN users u ON m.user_id = u.id`;
    let countSql = 'SELECT COUNT(*) as cnt FROM treehole_messages m';
    const params = [];
    const countParams = [];

    if (q) {
      const where = ' WHERE m.content LIKE ?';
      sql += where;
      countSql += where;
      params.push(`%${q}%`);
      countParams.push(`%${q}%`);
    }

    sql += ' ORDER BY m.created_at DESC LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const total = db.prepare(countSql).get(...countParams)?.cnt || 0;
    const messages = db.prepare(sql).all(...params);

    res.json({ messages, total, page, totalPages: Math.ceil(total / limit) || 1 });
  } catch (e) { res.status(500).json({ message: '获取留言失败' }); }
});

// ── Toggle message visibility ──
router.post('/treehole/:id/toggle', adminAuth, (req, res) => {
  try {
    const msg = db.prepare('SELECT id, is_visible FROM treehole_messages WHERE id = ?').get(req.params.id);
    if (!msg) return res.status(404).json({ message: '留言不存在' });

    const newVis = msg.is_visible ? 0 : 1;
    db.prepare('UPDATE treehole_messages SET is_visible = ? WHERE id = ?').run(newVis, msg.id);
    logAction(req.adminId, newVis ? 'show_message' : 'hide_message', 'treehole_message', msg.id, `Set is_visible=${newVis}`);
    res.json({ message: newVis ? '已显示' : '已隐藏', is_visible: newVis });
  } catch (e) { res.status(500).json({ message: '操作失败' }); }
});

// ── Delete message ──
router.delete('/treehole/:id', adminAuth, (req, res) => {
  try {
    const msg = db.prepare('SELECT id FROM treehole_messages WHERE id = ?').get(req.params.id);
    if (!msg) return res.status(404).json({ message: '留言不存在' });

    db.prepare('DELETE FROM treehole_interactions WHERE message_id = ?').run(msg.id);
    db.prepare('DELETE FROM treehole_comments WHERE message_id = ?').run(msg.id);
    db.prepare('DELETE FROM treehole_messages WHERE id = ?').run(msg.id);
    logAction(req.adminId, 'delete_message', 'treehole_message', msg.id, 'Deleted with interactions and comments');
    res.json({ message: '已删除' });
  } catch (e) { res.status(500).json({ message: '删除失败' }); }
});

// ── Comments list ──
router.get('/comments', adminAuth, (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;

    const total = db.prepare('SELECT COUNT(*) as cnt FROM treehole_comments').get()?.cnt || 0;
    const comments = db.prepare(`
      SELECT c.id, c.message_id, c.content, c.is_visible,
             u.phone,
             strftime('%Y-%m-%dT%H:%M:%SZ', c.created_at) AS created_at
      FROM treehole_comments c
      LEFT JOIN users u ON c.user_id = u.id
      ORDER BY c.created_at DESC LIMIT ? OFFSET ?
    `).all(limit, offset);

    res.json({ comments, total, page, totalPages: Math.ceil(total / limit) || 1 });
  } catch (e) { res.status(500).json({ message: '获取评论失败' }); }
});

// ── Delete comment ──
router.delete('/comments/:id', adminAuth, (req, res) => {
  try {
    const comment = db.prepare('SELECT id FROM treehole_comments WHERE id = ?').get(req.params.id);
    if (!comment) return res.status(404).json({ message: '评论不存在' });

    db.prepare('DELETE FROM treehole_comments WHERE id = ?').run(comment.id);
    logAction(req.adminId, 'delete_comment', 'treehole_comment', comment.id, 'Deleted');
    res.json({ message: '已删除' });
  } catch (e) { res.status(500).json({ message: '删除失败' }); }
});

// ── Sensitive words ──
router.get('/sensitive-words', adminAuth, (_req, res) => {
  try {
    const words = db.prepare('SELECT id, word, strftime(\'%Y-%m-%dT%H:%M:%SZ\', created_at) AS created_at FROM sensitive_words ORDER BY id').all();
    res.json({ words });
  } catch (e) { res.status(500).json({ message: '获取敏感词失败' }); }
});

router.post('/sensitive-words', adminAuth, (req, res) => {
  try {
    const word = String(req.body.word || '').trim();
    if (!word) return res.status(400).json({ message: '请输入敏感词' });

    const existing = db.prepare('SELECT id FROM sensitive_words WHERE word = ?').get(word);
    if (existing) return res.status(409).json({ message: '该敏感词已存在' });

    const result = db.prepare('INSERT INTO sensitive_words (word) VALUES (?)').run(word);
    invalidateCache();
    logAction(req.adminId, 'add_sensitive_word', 'sensitive_word', result.lastInsertRowid, `Added: ${word}`);
    res.json({ id: result.lastInsertRowid, message: '已添加' });
  } catch (e) { res.status(500).json({ message: '添加失败' }); }
});

router.delete('/sensitive-words/:id', adminAuth, (req, res) => {
  try {
    const word = db.prepare('SELECT id, word FROM sensitive_words WHERE id = ?').get(req.params.id);
    if (!word) return res.status(404).json({ message: '敏感词不存在' });

    db.prepare('DELETE FROM sensitive_words WHERE id = ?').run(word.id);
    invalidateCache();
    logAction(req.adminId, 'delete_sensitive_word', 'sensitive_word', word.id, `Deleted: ${word.word}`);
    res.json({ message: '已删除' });
  } catch (e) { res.status(500).json({ message: '删除失败' }); }
});

// ── Operation logs ──
router.get('/logs', adminAuth, (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 30;
    const offset = (page - 1) * limit;

    const total = db.prepare('SELECT COUNT(*) as cnt FROM admin_logs').get()?.cnt || 0;
    const logs = db.prepare(`
      SELECT l.id, l.admin_id, a.username, l.action, l.target_type, l.target_id, l.detail,
             strftime('%Y-%m-%dT%H:%M:%SZ', l.created_at) AS created_at
      FROM admin_logs l
      LEFT JOIN admin_users a ON l.admin_id = a.id
      ORDER BY l.created_at DESC LIMIT ? OFFSET ?
    `).all(limit, offset);

    res.json({ logs, total, page, totalPages: Math.ceil(total / limit) || 1 });
  } catch (e) { res.status(500).json({ message: '获取日志失败' }); }
});

module.exports = router;
