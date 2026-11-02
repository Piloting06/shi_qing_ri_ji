const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const router = express.Router();

// Get current date in China Standard Time (UTC+8)
function cstDate(daysOffset = 0) {
  const d = new Date(Date.now() + 8 * 3600000 + daysOffset * 86400000);
  return d.toISOString().slice(0, 10);
}

router.post('/', auth, (req, res) => {
  try {
    const today = cstDate();
    const existing = db.prepare('SELECT id, consecutive_days FROM checkins WHERE user_id = ? AND date = ?').get(req.userId, today);
    if (existing) return res.json({ consecutive_days: existing.consecutive_days, message: '今天已签到' });
    const yesterday = cstDate(-1);
    const prev = db.prepare('SELECT consecutive_days FROM checkins WHERE user_id = ? AND date = ?').get(req.userId, yesterday);
    const consecutive = (prev?.consecutive_days || 0) + 1;
    db.prepare('INSERT INTO checkins (user_id, date, consecutive_days) VALUES (?,?,?)').run(req.userId, today, consecutive);
    res.json({ consecutive_days: consecutive, message: '签到成功' });
  } catch (e) { res.status(500).json({ message: '签到失败' }); }
});

router.get('/status', auth, (req, res) => {
  const today = cstDate();
  const todayCheckin = db.prepare('SELECT * FROM checkins WHERE user_id = ? AND date = ?').get(req.userId, today);
  res.json({ checked_in: !!todayCheckin, consecutive_days: todayCheckin?.consecutive_days || 0 });
});

router.get('/card/today', auth, (req, res) => {
  res.json({ date: cstDate(), card: null, message: '卡片功能即将上线' });
});

module.exports = router;
