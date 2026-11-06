const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const DB_PATH = path.join(__dirname, 'xinqingriji.db');
// 备份目录：项目内 + 宿主机另一路径各一份，防单目录损坏
const BACKUP_DIR = process.env.DB_BACKUP_DIR || path.join(__dirname, 'backups');
const BACKUP_DIR_EXTERNAL = process.env.DB_BACKUP_DIR_EXTERNAL || '/root/db_backup';
const BACKUP_KEEP = 14; // 项目内保留份数
const FLUSH_DEBOUNCE_MS = 500; // 合并短时间内的连续写
const FLUSH_MAX_MS = 5000; // 持续写入时的最大落盘延迟

let db = null;
let dirty = false;
let flushTimer = null;
let firstDirtyAt = 0;
let flushing = false;

// ── 持久化：防抖合并 + 原子替换 ──
// 旧实现每次写操作全量 export + writeFileSync，既慢（O(全库)）又可能
// 在写入中途被杀导致库损坏。现改为：标记脏位 → 防抖合并 → 写临时文件
// fsync 后 rename 原子替换。
function flushNow() {
  if (!db || !dirty || flushing) return;
  flushing = true;
  try {
    const data = Buffer.from(db.export());
    const tmp = DB_PATH + '.tmp';
    const fd = fs.openSync(tmp, 'w');
    try {
      fs.writeSync(fd, data);
      fs.fsyncSync(fd);
    } finally {
      fs.closeSync(fd);
    }
    fs.renameSync(tmp, DB_PATH);
    dirty = false;
  } finally {
    flushing = false;
  }
  if (dirty) scheduleFlush(); // 落盘期间又有新写入
}

function scheduleFlush() {
  if (!firstDirtyAt) firstDirtyAt = Date.now();
  dirty = true;
  if (flushTimer) return;
  const waited = Date.now() - firstDirtyAt;
  const delay = Math.max(0, Math.min(FLUSH_DEBOUNCE_MS, FLUSH_MAX_MS - waited));
  flushTimer = setTimeout(() => {
    flushTimer = null;
    firstDirtyAt = 0;
    flushNow();
  }, delay);
}

// 强制立即落盘（保留原导出接口语义）
function saveDb() {
  if (flushTimer) {
    clearTimeout(flushTimer);
    flushTimer = null;
    firstDirtyAt = 0;
  }
  dirty = true;
  flushNow();
}

function flushOnExit() {
  if (flushTimer) {
    clearTimeout(flushTimer);
    flushTimer = null;
  }
  flushNow();
}
process.on('exit', flushOnExit);
for (const sig of ['SIGINT', 'SIGTERM']) {
  process.on(sig, () => {
    flushOnExit();
    process.exit(0);
  });
}
process.on('uncaughtException', (err) => {
  // 崩溃前尽量把内存里的数据落盘，再原样抛出交给 pm2 重启
  try {
    flushOnExit();
  } catch (_) {}
  throw err;
});

// ── 备份：每日一份，双目录，自动清理 ──
function pad2(n) {
  return String(n).padStart(2, '0');
}
function localDateStamp(d = new Date()) {
  return `${d.getFullYear()}${pad2(d.getMonth() + 1)}${pad2(d.getDate())}`;
}
function backupDb() {
  flushNow();
  if (!fs.existsSync(DB_PATH)) return;
  const now = new Date();
  const stamp = `${localDateStamp(now)}-${pad2(now.getHours())}${pad2(now.getMinutes())}`;
  const name = `xinqingriji-${stamp}.db`;
  try {
    fs.mkdirSync(BACKUP_DIR, { recursive: true });
    fs.copyFileSync(DB_PATH, path.join(BACKUP_DIR, name));
    fs.mkdirSync(BACKUP_DIR_EXTERNAL, { recursive: true });
    fs.copyFileSync(DB_PATH, path.join(BACKUP_DIR_EXTERNAL, name));
    // 清理过期备份，只保留最近 BACKUP_KEEP 份
    const old = fs
      .readdirSync(BACKUP_DIR)
      .filter((f) => /^xinqingriji-\d{8}-\d{4}\.db$/.test(f))
      .sort()
      .slice(0, -BACKUP_KEEP);
    for (const f of old) fs.unlinkSync(path.join(BACKUP_DIR, f));
    console.log(`[Backup] 已备份 ${name}`);
  } catch (err) {
    console.error('[Backup] 备份失败:', err.message);
  }
}

let lastBackupDate = '';
function dailyBackupTick() {
  const today = localDateStamp();
  if (lastBackupDate && lastBackupDate !== today) backupDb();
  lastBackupDate = today;
}

function exec(sql) {
  db.exec(sql);
  scheduleFlush();
}

// Helper to get last insert rowid
function getLastId() {
  const r = db.exec('SELECT last_insert_rowid() as id');
  return r[0]?.values?.[0]?.[0] || 0;
}

// Wrapper mimicking better-sqlite3 API
function prepare(sql) {
  return {
    run: (...params) => {
      db.run(sql, params);
      scheduleFlush();
      return { lastInsertRowid: getLastId(), changes: db.getRowsModified() };
    },
    get: (...params) => {
      const stmt = db.prepare(sql);
      if (params.length > 0) stmt.bind(params);
      let result = null;
      if (stmt.step()) result = stmt.getAsObject();
      stmt.free();
      return result;
    },
    all: (...params) => {
      const stmt = db.prepare(sql);
      if (params.length > 0) stmt.bind(params);
      const results = [];
      while (stmt.step()) results.push(stmt.getAsObject());
      stmt.free();
      return results;
    }
  };
}

async function init() {
  const SQL = await initSqlJs();
  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    db = new SQL.Database(buffer);
  } else {
    db = new SQL.Database();
  }

  db.run('PRAGMA foreign_keys = ON');

  const tables = [
    `CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT UNIQUE NOT NULL,
      username TEXT NOT NULL,
      password_hash TEXT NOT NULL,
      security_question_type TEXT,
      security_question TEXT,
      security_answer_hash TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      is_active INTEGER DEFAULT 1,
      deleted_at TEXT
    )`,
    `CREATE TABLE IF NOT EXISTS moods (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      emotion_type INTEGER NOT NULL,
      emotion_tags TEXT,
      notes TEXT,
      weather_code TEXT,
      weather_temp_max REAL,
      weather_temp_min REAL,
      weather_rain_prob INTEGER,
      ai_response TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS mood_comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      mood_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      deleted_at TEXT,
      FOREIGN KEY (mood_id) REFERENCES moods(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS checkins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      date TEXT NOT NULL,
      consecutive_days INTEGER DEFAULT 0,
      card_content TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS friendships (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      friend_id INTEGER NOT NULL,
      status INTEGER DEFAULT 0,
      permission_expires_at TEXT,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id),
      FOREIGN KEY (friend_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS friend_notes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sender_id INTEGER NOT NULL,
      receiver_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (sender_id) REFERENCES users(id),
      FOREIGN KEY (receiver_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS treehole_messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      cloud_hugs INTEGER DEFAULT 0,
      cloud_coffees INTEGER DEFAULT 0,
      is_visible INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS treehole_interactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      interaction_type TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(message_id, user_id, interaction_type)
    )`,
    `CREATE TABLE IF NOT EXISTS time_capsules (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      open_date TEXT NOT NULL,
      is_opened INTEGER DEFAULT 0,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS push_cache (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      push_type TEXT NOT NULL,
      content TEXT NOT NULL,
      generated_at TEXT,
      is_sent INTEGER DEFAULT 0
    )`,
    `CREATE TABLE IF NOT EXISTS treehole_comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      is_visible INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (message_id) REFERENCES treehole_messages(id),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS sensitive_words (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      word TEXT UNIQUE NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )`,
    `CREATE TABLE IF NOT EXISTS admin_users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      username TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TEXT DEFAULT (datetime('now'))
    )`,
    `CREATE TABLE IF NOT EXISTS admin_token_blacklist (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      token_hash TEXT UNIQUE NOT NULL,
      expired_at TEXT NOT NULL
    )`,
    `CREATE TABLE IF NOT EXISTS admin_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      admin_id INTEGER NOT NULL,
      action TEXT NOT NULL,
      target_type TEXT,
      target_id INTEGER,
      detail TEXT,
      created_at TEXT DEFAULT (datetime('now'))
    )`,
    `CREATE TABLE IF NOT EXISTS city_comments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      city_code TEXT NOT NULL,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      likes INTEGER DEFAULT 0,
      is_visible INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (user_id) REFERENCES users(id)
    )`,
    `CREATE TABLE IF NOT EXISTS city_comment_likes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      comment_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      created_at TEXT DEFAULT (datetime('now')),
      UNIQUE(comment_id, user_id)
    )`,
    `CREATE TABLE IF NOT EXISTS city_comment_replies (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      comment_id INTEGER NOT NULL,
      user_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      is_visible INTEGER DEFAULT 1,
      created_at TEXT DEFAULT (datetime('now')),
      FOREIGN KEY (comment_id) REFERENCES city_comments(id)
    )`,
    `CREATE TABLE IF NOT EXISTS sms_codes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      phone TEXT NOT NULL,
      code TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      used INTEGER DEFAULT 0
    )`,
  ];

  for (const sql of tables) {
    db.run(sql);
  }

  const userColumns = db.exec('PRAGMA table_info(users)')[0]?.values?.map((row) => row[1]) || [];
  if (!userColumns.includes('deleted_at')) {
    db.run('ALTER TABLE users ADD COLUMN deleted_at TEXT');
  }
  if (!userColumns.includes('email')) {
    db.run('ALTER TABLE users ADD COLUMN email TEXT');
  }

  // 胶囊邮件通知标记
  const capsuleCols = db.exec('PRAGMA table_info(time_capsules)')[0]?.values?.map((row) => row[1]) || [];
  if (!capsuleCols.includes('email_notified')) {
    db.run('ALTER TABLE time_capsules ADD COLUMN email_notified INTEGER DEFAULT 0');
  }

  // 验证码错误次数（错满 5 次作废）
  const codeCols = db.exec('PRAGMA table_info(sms_codes)')[0]?.values?.map((row) => row[1]) || [];
  if (!codeCols.includes('attempts')) {
    db.run('ALTER TABLE sms_codes ADD COLUMN attempts INTEGER DEFAULT 0');
  }

  // 心情记录关联城市（城迹·城市心晴榜）
  const moodCols = db.exec('PRAGMA table_info(moods)')[0]?.values?.map((row) => row[1]) || [];
  if (!moodCols.includes('city')) {
    db.run('ALTER TABLE moods ADD COLUMN city TEXT');
  }

  saveDb();

  // 启动 1 分钟后做当天首次备份，之后每 10 分钟检查一次跨天
  lastBackupDate = localDateStamp();
  setTimeout(backupDb, 60 * 1000);
  setInterval(dailyBackupTick, 10 * 60 * 1000);

  console.log('Database initialized');
}

module.exports = { db: { exec, prepare, saveDb, backupDb }, init };
