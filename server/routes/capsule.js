const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const router = express.Router();

function cstDate(daysOffset = 0) {
  const d = new Date(Date.now() + 8 * 3600000 + daysOffset * 86400000);
  return d.toISOString().slice(0, 10);
}

router.post('/', auth, (req, res) => {
  try {
    const content = String(req.body.content || '').trim();
    const openDate = String(req.body.open_date || '').trim();
    if (!content || !openDate) {
      return res.status(400).json({ message: '请填写完整的胶囊内容和开启日期' });
    }
    if (content.length > 500) {
      return res.status(400).json({ message: '内容最多 500 字' });
    }
    if (openDate < cstDate()) {
      return res.status(400).json({ message: '打开日期不能早于今天' });
    }

    const existing = db.prepare(`
      SELECT id, open_date FROM time_capsules
      WHERE user_id = ? AND content = ? AND open_date = ? AND is_opened = 0
      ORDER BY id DESC
      LIMIT 1
    `).get(req.userId, content, openDate);
    if (existing) {
      return res.json({
        id: existing.id,
        open_date: existing.open_date,
        message: '这颗胶囊已经封存好了',
      });
    }

    const result = db.prepare(
      'INSERT INTO time_capsules (user_id, content, open_date) VALUES (?,?,?)',
    ).run(req.userId, content, openDate);
    res.json({
      id: result.lastInsertRowid,
      open_date: openDate,
      message: '胶囊已封存',
    });
  } catch (e) {
    res.status(500).json({ message: '创建失败' });
  }
});

router.get('/list', auth, (req, res) => {
  try {
    const capsules = db.prepare(`
      SELECT id, open_date, is_opened,
      strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at,
      CASE WHEN is_opened = 1 THEN content ELSE NULL END AS content
      FROM time_capsules
      WHERE user_id = ?
      ORDER BY open_date ASC, id DESC
    `).all(req.userId);
    res.json({ capsules, today: cstDate() });
  } catch (e) {
    res.status(500).json({ message: '获取胶囊失败' });
  }
});

router.get('/:id', auth, (req, res) => {
  try {
    const capsule = db.prepare(`
      SELECT id, user_id, content, open_date, is_opened,
      strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at
      FROM time_capsules
      WHERE id = ? AND user_id = ?
    `).get(req.params.id, req.userId);

    if (!capsule) {
      return res.status(404).json({ message: '胶囊不存在或已被移走' });
    }

    if (String(capsule.open_date) > cstDate()) {
      return res.status(403).json({
        message: `${capsule.open_date} 才能打开这颗胶囊`,
      });
    }

    db.prepare('UPDATE time_capsules SET is_opened = 1 WHERE id = ?').run(
      req.params.id,
    );
    res.json({ ...capsule, is_opened: 1 });
  } catch (e) {
    res.status(500).json({ message: '打开胶囊失败，请稍后再试' });
  }
});

router.delete('/:id', auth, (req, res) => {
  try {
    const cap = db.prepare('SELECT id, user_id, is_opened FROM time_capsules WHERE id = ?').get(req.params.id);
    if (!cap) return res.status(404).json({ message: '胶囊不存在' });
    if (cap.user_id !== req.userId) return res.status(403).json({ message: '只能删除自己的胶囊' });
    if (!cap.is_opened) return res.status(400).json({ message: '只能删除已打开的胶囊' });
    db.prepare('DELETE FROM time_capsules WHERE id = ?').run(req.params.id);
    res.json({ message: '胶囊已删除' });
  } catch (e) { res.status(500).json({ message: '删除失败' }); }
});

module.exports = router;
