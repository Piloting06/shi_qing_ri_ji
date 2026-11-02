const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const { sendFeedback } = require('../mail');
const router = express.Router();

router.post('/', auth, async (req, res) => {
  try {
    const content = String(req.body.content || '').trim();
    if (!content) {
      return res.status(400).json({ message: '请填写反馈内容' });
    }
    if (content.length > 1000) {
      return res.status(400).json({ message: '反馈内容最多 1000 字' });
    }

    const userId = req.userId;
    const user = db.prepare('SELECT username, phone FROM users WHERE id = ?').get(userId);
    const username = user?.username || '未知用户';
    const phone = user?.phone || '未绑定';

    await sendFeedback({ userId, username, phone, content });
    res.json({ message: '反馈已发送，感谢你的建议' });
  } catch (err) {
    console.error('[Feedback]', err.message);
    res.status(500).json({ message: '发送失败，请稍后重试' });
  }
});

module.exports = router;
