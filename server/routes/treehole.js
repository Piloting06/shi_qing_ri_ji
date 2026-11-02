const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const { containsSensitive } = require('../sensitive_words');
const router = express.Router();

const INTERACTIONS = {
  cloud_hug: 'cloud_hugs',
  cloud_coffee: 'cloud_coffees',
};

function countsFor(messageId) {
  const row = db.prepare('SELECT cloud_hugs, cloud_coffees FROM treehole_messages WHERE id = ?').get(messageId);
  return {
    cloud_hugs: row?.cloud_hugs || 0,
    cloud_coffees: row?.cloud_coffees || 0,
  };
}

router.get('/', auth, (req, res) => {
  try {
    const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
    const limit = 20;
    const offset = (page - 1) * limit;
    const messages = db.prepare(
      "SELECT id, user_id, content, cloud_hugs, cloud_coffees, strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at FROM treehole_messages WHERE is_visible = 1 ORDER BY created_at DESC LIMIT ? OFFSET ?"
    ).all(limit, offset);

    const messageIds = messages.map((m) => m.id);
    const interactionsByMessage = new Map();
    if (messageIds.length > 0) {
      const placeholders = messageIds.map(() => '?').join(',');
      const rows = db.prepare(`
        SELECT message_id, interaction_type
        FROM treehole_interactions
        WHERE user_id = ? AND message_id IN (${placeholders})
      `).all(req.userId, ...messageIds);
      for (const row of rows) {
        const interactions = interactionsByMessage.get(row.message_id) || [];
        interactions.push(row.interaction_type);
        interactionsByMessage.set(row.message_id, interactions);
      }
    }

    // Count comments per message
    const commentCounts = new Map();
    try {
      const commentRows = db.prepare(
        `SELECT message_id, COUNT(*) as cnt FROM treehole_comments
         WHERE message_id IN (${messageIds.map(() => '?').join(',')}) AND is_visible = 1
         GROUP BY message_id`
      ).all(...messageIds);
      for (const r of commentRows) {
        commentCounts.set(r.message_id, r.cnt);
      }
    } catch (_) {}

    const result = messages.map((m) => ({
      id: m.id,
      content: m.content,
      cloud_hugs: m.cloud_hugs || 0,
      cloud_coffees: m.cloud_coffees || 0,
      created_at: m.created_at,
      is_own: Number(m.user_id) === Number(req.userId),
      interactions: interactionsByMessage.get(m.id) || [],
      comment_count: commentCounts.get(m.id) || 0,
    }));

    res.json({ messages: result, page });
  } catch (e) { res.status(500).json({ message: '获取树洞失败' }); }
});

router.post('/', auth, (req, res) => {
  try {
    const content = String(req.body.content || '').trim();
    if (!content) return res.status(400).json({ message: '内容不能为空' });
    if (content.length > 200) return res.status(400).json({ message: '最多写 200 字' });
    if (containsSensitive(content)) {
      return res.status(400).json({ message: '内容里有不适合发布的词，改一下再发吧' });
    }

    const beijingToday = new Date(Date.now() + 8 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    const startMs = Date.parse(`${beijingToday}T00:00:00+08:00`);
    const startUtc = new Date(startMs).toISOString().slice(0, 19).replace('T', ' ');
    const endUtc = new Date(startMs + 86400000).toISOString().slice(0, 19).replace('T', ' ');
    const count = db.prepare(
      'SELECT COUNT(*) as cnt FROM treehole_messages WHERE user_id = ? AND created_at >= ? AND created_at < ?'
    ).get(req.userId, startUtc, endUtc).cnt;
    if (count >= 3) return res.status(429).json({ message: '今天已发3条，明天再来吧' });

    db.prepare('INSERT INTO treehole_messages (user_id, content) VALUES (?,?)').run(req.userId, content);
    res.json({ message: '留言成功' });
  } catch (e) { res.status(500).json({ message: '留言失败' }); }
});

router.post('/:id/interact', auth, (req, res) => {
  try {
    const interactionType = String(req.body.interaction_type || '');
    const col = INTERACTIONS[interactionType];
    if (!col) return res.status(400).json({ message: '互动类型无效' });

    const msgId = req.params.id;
    const message = db.prepare('SELECT id FROM treehole_messages WHERE id = ? AND is_visible = 1').get(msgId);
    if (!message) return res.status(404).json({ message: '留言不存在' });

    const existing = db.prepare('SELECT id FROM treehole_interactions WHERE message_id = ? AND user_id = ? AND interaction_type = ?')
      .get(msgId, req.userId, interactionType);
    if (existing) {
      return res.status(409).json({ message: '已经送过啦', counts: countsFor(msgId) });
    }

    db.prepare('INSERT INTO treehole_interactions (message_id, user_id, interaction_type) VALUES (?,?,?)')
      .run(msgId, req.userId, interactionType);
    db.prepare(`UPDATE treehole_messages SET ${col} = ${col} + 1 WHERE id = ?`).run(msgId);
    res.json({ message: '互动成功', counts: countsFor(msgId), interaction_type: interactionType });
  } catch (e) { res.status(500).json({ message: '互动失败' }); }
});

// ══════════════════════════════════════════
//  匿名评论
// ══════════════════════════════════════════

router.get('/:id/comments', auth, (req, res) => {
  try {
    const msgId = req.params.id;
    const message = db.prepare('SELECT id FROM treehole_messages WHERE id = ? AND is_visible = 1').get(msgId);
    if (!message) return res.status(404).json({ message: '留言不存在' });

    const comments = db.prepare(`
      SELECT id, message_id, content, is_own,
      strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at
      FROM (
        SELECT c.id, c.message_id, c.content, c.created_at,
               CASE WHEN c.user_id = ? THEN 1 ELSE 0 END AS is_own
        FROM treehole_comments c
        WHERE c.message_id = ? AND c.is_visible = 1
        ORDER BY c.created_at ASC
        LIMIT 50
      )
    `).all(req.userId, msgId);

    res.json({ comments });
  } catch (e) { res.status(500).json({ message: '获取评论失败' }); }
});

router.post('/:id/comments', auth, (req, res) => {
  try {
    const msgId = req.params.id;
    const content = String(req.body.content || '').trim();

    if (!content) return res.status(400).json({ message: '评论不能为空' });
    if (content.length > 200) return res.status(400).json({ message: '评论最多 200 字' });
    if (containsSensitive(content)) {
      return res.status(400).json({ message: '评论里有不适合发布的词，改一下再发吧' });
    }

    const message = db.prepare('SELECT id FROM treehole_messages WHERE id = ? AND is_visible = 1').get(msgId);
    if (!message) return res.status(404).json({ message: '留言不存在' });

    const result = db.prepare(
      'INSERT INTO treehole_comments (message_id, user_id, content) VALUES (?,?,?)'
    ).run(msgId, req.userId, content);

    res.json({ id: result.lastInsertRowid, message: '评论已发送' });
  } catch (e) { res.status(500).json({ message: '评论失败' }); }
});

router.delete('/:id', auth, (req, res) => {
  try {
    const msg = db.prepare('SELECT id, user_id FROM treehole_messages WHERE id = ? AND is_visible = 1').get(req.params.id);
    if (!msg) return res.status(404).json({ message: '留言不存在' });
    if (msg.user_id !== req.userId) return res.status(403).json({ message: '只能撤回自己的留言' });
    db.prepare('UPDATE treehole_messages SET is_visible = 0 WHERE id = ?').run(req.params.id);
    res.json({ message: '已撤回' });
  } catch (e) { res.status(500).json({ message: '撤回失败' }); }
});

module.exports = router;
