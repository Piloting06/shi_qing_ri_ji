const express = require('express');
const auth = require('../middleware/auth');
const { db } = require('../db');
const router = express.Router();

function isFuture(value) {
  return Boolean(value) && Date.parse(value) > Date.now();
}

function canViewMood(viewerId, ownerId) {
  const rows = db.prepare(`
    SELECT user_id, friend_id, permission_expires_at FROM friendships
    WHERE ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?))
    AND status = 1
  `).all(viewerId, ownerId, ownerId, viewerId);

  return rows.some((row) => (
    Number(row.user_id) === Number(viewerId) &&
    Number(row.friend_id) === Number(ownerId) &&
    isFuture(row.permission_expires_at)
  ));
}

function normalizePhone(value) {
  return String(value || '').trim().replace(/\s+/g, '');
}

function isCompletePhone(value) {
  return /^1\d{10}$/.test(value);
}

function activeRelation(userId, targetId) {
  return db.prepare(`
    SELECT id, user_id, friend_id, status FROM friendships
    WHERE ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?))
    AND status IN (0, 1)
    ORDER BY status DESC, id DESC
    LIMIT 1
  `).get(userId, targetId, targetId, userId);
}

function areFriends(userId, targetId) {
  const relation = activeRelation(userId, targetId);
  return Boolean(relation) && Number(relation.status) === 1;
}

router.post('/add', auth, (req, res) => {
  try {
    const phone = normalizePhone(req.body.phone);
    if (!isCompletePhone(phone)) return res.status(400).json({ message: '请输入完整手机号' });

    const target = db.prepare('SELECT id, username FROM users WHERE phone = ? AND is_active = 1').get(phone);
    if (!target) return res.status(404).json({ message: '未找到该用户' });
    if (Number(target.id) === Number(req.userId)) return res.status(400).json({ message: '不能添加自己' });

    const exist = activeRelation(req.userId, target.id);
    if (exist) {
      if (Number(exist.status) === 1) return res.status(409).json({ message: '已是好友' });
      if (Number(exist.user_id) === Number(req.userId)) {
        return res.status(409).json({ message: '已发送过请求，等待对方处理' });
      }
      return res.status(409).json({ message: '对方已发送申请，请到好友请求里处理' });
    }

    db.prepare('INSERT INTO friendships (user_id, friend_id, status) VALUES (?,?,0)').run(req.userId, target.id);
    res.json({ message: '好友请求已发送' });
  } catch (e) { res.status(500).json({ message: '添加失败' }); }
});

router.get('/search', auth, (req, res) => {
  try {
    const q = normalizePhone(req.query.q);
    if (!isCompletePhone(q)) return res.status(400).json({ message: '请输入完整手机号' });

    const user = db.prepare(`
      SELECT id, phone, username FROM users
      WHERE phone = ? AND is_active = 1 AND id != ?
      LIMIT 1
    `).get(q, req.userId);

    if (!user) return res.json({ users: [] });

    const relation = activeRelation(req.userId, user.id);
    res.json({
      users: [{
        ...user,
        relation_status: relation ? relation.status : null,
        relation_direction: relation
          ? (Number(relation.user_id) === Number(req.userId) ? 'sent' : 'received')
          : null,
      }],
    });
  } catch (e) { res.status(500).json({ message: '搜索失败' }); }
});

router.get('/requests', auth, (req, res) => {
  try {
    const requests = db.prepare(`
      SELECT f.id, f.user_id, f.status, u.username, u.phone FROM friendships f
      JOIN users u ON f.user_id = u.id
      WHERE f.friend_id = ? AND f.status = 0
      ORDER BY f.created_at DESC
    `).all(req.userId);
    res.json({ requests });
  } catch (e) { res.status(500).json({ message: '获取请求失败' }); }
});

router.post('/respond', auth, (req, res) => {
  try {
    const { id, status, can_view_mood } = req.body;
    const statusNum = parseInt(status, 10);
    if (statusNum !== 1 && statusNum !== -1) {
      return res.status(400).json({ message: '无效的状态值' });
    }

    const existing = db.prepare('SELECT id, user_id, friend_id FROM friendships WHERE id = ? AND friend_id = ? AND status = 0')
      .get(id, req.userId);
    if (!existing) return res.status(404).json({ message: '请求不存在或已处理' });

    const expires = statusNum === 1 && can_view_mood
      ? new Date(Date.now() + 7 * 86400000).toISOString()
      : null;
    db.prepare('UPDATE friendships SET status = ?, permission_expires_at = ? WHERE id = ? AND friend_id = ?')
      .run(statusNum, expires, id, req.userId);

    if (statusNum === 1) {
      db.prepare(`
        DELETE FROM friendships
        WHERE id != ?
        AND ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?))
        AND status IN (0, 1)
      `).run(existing.id, existing.user_id, existing.friend_id, existing.friend_id, existing.user_id);
    }

    res.json({ message: '已处理' });
  } catch (e) { res.status(500).json({ message: '处理失败' }); }
});

router.get('/list', auth, (req, res) => {
  try {
    const rows = db.prepare(`
      SELECT
        f.id AS friendship_id,
        f.user_id,
        f.friend_id,
        f.status,
        f.permission_expires_at,
        CASE WHEN f.user_id = ? THEN f.friend_id ELSE f.user_id END AS id,
        u.username,
        u.phone,
        m.id AS latest_mood_id,
        m.date AS latest_mood_date,
        m.emotion_type AS latest_mood,
        m.notes AS latest_mood_notes
      FROM friendships f
      JOIN users u ON u.id = CASE WHEN f.user_id = ? THEN f.friend_id ELSE f.user_id END
      LEFT JOIN moods m ON m.id = (
        SELECT id FROM moods WHERE user_id = u.id ORDER BY date DESC, id DESC LIMIT 1
      )
      WHERE (f.user_id = ? OR f.friend_id = ?) AND f.status = 1 AND u.is_active = 1
      ORDER BY f.created_at DESC, f.id DESC
    `).all(req.userId, req.userId, req.userId, req.userId);

    const friendIds = [...new Set(rows.map((row) => Number(row.id)).filter(Number.isInteger))];
    const latestNotesByUser = new Map();
    if (friendIds.length > 0) {
      const placeholders = friendIds.map(() => '?').join(',');
      const latestNotes = db.prepare(`
        SELECT peer_id, id, content, sender_id, created_at FROM (
          SELECT
            CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END AS peer_id,
            id,
            content,
            sender_id,
            strftime('%Y-%m-%dT%H:%M:%SZ', created_at) AS created_at,
            ROW_NUMBER() OVER (
              PARTITION BY CASE WHEN sender_id = ? THEN receiver_id ELSE sender_id END
              ORDER BY created_at DESC, id DESC
            ) AS rn
          FROM friend_notes
          WHERE (sender_id = ? AND receiver_id IN (${placeholders}))
             OR (receiver_id = ? AND sender_id IN (${placeholders}))
        )
        WHERE rn = 1
      `).all(req.userId, req.userId, req.userId, ...friendIds, req.userId, ...friendIds);
      for (const note of latestNotes) latestNotesByUser.set(Number(note.peer_id), note);
    }

    const byUser = new Map();
    for (const row of rows) {
      const id = Number(row.id);
      const currentCanView = Number(row.user_id) === Number(req.userId) &&
        Number(row.friend_id) === id &&
        isFuture(row.permission_expires_at);
      const friendCanView = Number(row.friend_id) === Number(req.userId) &&
        Number(row.user_id) === id &&
        isFuture(row.permission_expires_at);

      if (!byUser.has(id)) {
        const latestNote = latestNotesByUser.get(id);

        byUser.set(id, {
          ...row,
          id,
          latest_mood_id: currentCanView ? row.latest_mood_id : null,
          latest_mood_date: currentCanView ? row.latest_mood_date : null,
          latest_mood: currentCanView ? row.latest_mood : null,
          latest_mood_notes: currentCanView ? row.latest_mood_notes : null,
          latest_note: latestNote?.content || null,
          latest_note_created_at: latestNote?.created_at || null,
          latest_note_is_mine: latestNote ? Number(latestNote.sender_id) === Number(req.userId) : false,
          can_view_mood: currentCanView,
          friend_can_view_my_mood: friendCanView,
        });
      } else {
        const existing = byUser.get(id);
        existing.can_view_mood = existing.can_view_mood || currentCanView;
        existing.friend_can_view_my_mood = existing.friend_can_view_my_mood || friendCanView;
      }
    }

    res.json({ friends: Array.from(byUser.values()) });
  } catch (e) { res.status(500).json({ message: '获取好友列表失败' }); }
});

router.delete('/:friendId', auth, (req, res) => {
  try {
    const friendId = Number(req.params.friendId);
    if (!Number.isInteger(friendId) || friendId <= 0 || friendId === Number(req.userId)) {
      return res.status(400).json({ message: '好友无效' });
    }

    const result = db.prepare(`
      DELETE FROM friendships
      WHERE ((user_id = ? AND friend_id = ?) OR (user_id = ? AND friend_id = ?))
      AND status IN (0, 1)
    `).run(req.userId, friendId, friendId, req.userId);

    if (result.changes === 0) return res.status(404).json({ message: '好友关系不存在' });
    res.json({ message: '已删除好友' });
  } catch (e) { res.status(500).json({ message: '删除好友失败' }); }
});

router.get('/moods/:moodId/comments', auth, (req, res) => {
  try {
    const mood = db.prepare('SELECT id, user_id FROM moods WHERE id = ?').get(req.params.moodId);
    if (!mood) return res.status(404).json({ message: '心情不存在' });
    if (Number(mood.user_id) !== Number(req.userId) && !canViewMood(req.userId, mood.user_id)) {
      return res.status(403).json({ message: '无权查看评论' });
    }

    const comments = db.prepare(`
      SELECT c.id, c.mood_id, c.user_id, c.content, c.created_at, u.username, u.phone
      FROM mood_comments c JOIN users u ON c.user_id = u.id
      WHERE c.mood_id = ? AND c.deleted_at IS NULL
      ORDER BY c.created_at ASC, c.id ASC
    `).all(req.params.moodId);

    res.json({ comments });
  } catch (e) { res.status(500).json({ message: '获取评论失败' }); }
});

router.post('/moods/:moodId/comments', auth, (req, res) => {
  try {
    const content = String(req.body.content || '').trim();
    if (!content) return res.status(400).json({ message: '请输入评论内容' });
    if (content.length > 200) return res.status(400).json({ message: '评论最多 200 字' });

    const mood = db.prepare('SELECT id, user_id FROM moods WHERE id = ?').get(req.params.moodId);
    if (!mood) return res.status(404).json({ message: '心情不存在' });
    if (Number(mood.user_id) === Number(req.userId) || !canViewMood(req.userId, mood.user_id)) {
      return res.status(403).json({ message: '无权评论这条心情' });
    }

    const result = db.prepare('INSERT INTO mood_comments (mood_id, user_id, content) VALUES (?,?,?)')
      .run(req.params.moodId, req.userId, content);
    res.json({ id: result.lastInsertRowid, message: '已评论' });
  } catch (e) { res.status(500).json({ message: '评论失败' }); }
});

router.post('/:id/note', auth, (req, res) => {
  try {
    const friendId = Number(req.params.id);
    const content = String(req.body.content || '').trim();
    if (!Number.isInteger(friendId) || friendId <= 0 || friendId === Number(req.userId)) {
      return res.status(400).json({ message: '好友无效' });
    }
    if (!content) return res.status(400).json({ message: '写一句话再送出去吧' });
    if (content.length > 80) return res.status(400).json({ message: '小纸条最多 80 字' });
    if (!areFriends(req.userId, friendId)) {
      return res.status(403).json({ message: '还不是好友，暂时不能留纸条' });
    }

    const result = db.prepare(
      'INSERT INTO friend_notes (sender_id, receiver_id, content) VALUES (?,?,?)'
    ).run(req.userId, friendId, content);

    res.json({
      id: result.lastInsertRowid,
      message: '小纸条已经放进对方的口袋里了',
    });
  } catch (e) { res.status(500).json({ message: '纸条发送失败' }); }
});

router.get('/:id/mood', auth, (req, res) => {
  try {
    const friendId = Number(req.params.id);
    if (!friendId || friendId === Number(req.userId)) return res.status(400).json({ message: '好友无效' });
    if (!canViewMood(req.userId, friendId)) return res.status(403).json({ message: '无权查看或授权已过期' });

    const moods = db.prepare(`
      SELECT id, date, emotion_type, emotion_tags, notes
      FROM moods
      WHERE user_id = ?
      ORDER BY date DESC, id DESC
      LIMIT 7
    `).all(friendId);
    res.json({ moods });
  } catch (e) { res.status(500).json({ message: '获取心情失败' }); }
});

module.exports = router;
