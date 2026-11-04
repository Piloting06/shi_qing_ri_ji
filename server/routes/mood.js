const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const router = express.Router();

// POST / — 新增一条心情记录（每次都是新记录，不覆盖）
/** YYYY-MM-DD 且是真实存在的日期 */
function isValidDate(s) {
  if (typeof s !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(s)) return false;
  const d = new Date(s + 'T00:00:00Z');
  return !Number.isNaN(d.getTime()) && d.toISOString().slice(0, 10) === s;
}

router.post('/', auth, (req, res) => {
  try {
    const { date, emotion_type, emotion_tags, notes, city, weather_code } = req.body;
    const type = Number(emotion_type);
    if (!Number.isInteger(type) || type < 1 || type > 8) return res.status(400).json({ message: '心情不对，重新选一个' });
    if (!isValidDate(date)) return res.status(400).json({ message: '日期不对' });
    if (notes != null && String(notes).length > 2000) return res.status(400).json({ message: '最多写 2000 字' });
    if (emotion_tags != null && String(emotion_tags).length > 500) return res.status(400).json({ message: '标签太多了' });
    const result = db.prepare(
      'INSERT INTO moods (user_id, date, emotion_type, emotion_tags, notes, city, weather_code) VALUES (?,?,?,?,?,?,?)'
    ).run(
      req.userId,
      date,
      type,
      emotion_tags ? String(emotion_tags) : '',
      notes ? String(notes) : '',
      city ? String(city).slice(0, 32) : null,
      weather_code == null ? null : String(weather_code)
    );
    res.json({ id: result.lastInsertRowid, message: '已保存' });
  } catch (e) { res.status(500).json({ message: '保存失败' }); }
});

// GET /?date=YYYY-MM-DD — 获取某天所有记录
router.get('/', auth, (req, res) => {
  try {
    const { date } = req.query;
    const moods = db.prepare(
      'SELECT * FROM moods WHERE user_id = ? AND date = ? ORDER BY created_at ASC'
    ).all(req.userId, date);
    res.json({ moods });
  } catch (e) { res.status(500).json({ message: '获取失败' }); }
});

// GET /all — 获取所有记录
router.get('/all', auth, (req, res) => {
  try {
    const moods = db.prepare(
      'SELECT * FROM moods WHERE user_id = ? ORDER BY date DESC, created_at DESC'
    ).all(req.userId);
    res.json({ moods });
  } catch (e) { res.status(500).json({ message: '获取失败' }); }
});

// DELETE /:id — 删除单条记录
router.delete('/:id', auth, (req, res) => {
  try {
    const { id } = req.params;
    const mood = db.prepare('SELECT id FROM moods WHERE id = ? AND user_id = ?').get(id, req.userId);
    if (!mood) return res.status(404).json({ message: '记录不存在' });
    db.prepare('DELETE FROM moods WHERE id = ?').run(id);
    res.json({ message: '已删除' });
  } catch (e) { res.status(500).json({ message: '删除失败' }); }
});

module.exports = router;
