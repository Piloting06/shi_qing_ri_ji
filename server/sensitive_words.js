const { db } = require('./db');

// In-memory cache
let _words = null;
let _lastFetch = 0;
const CACHE_TTL = 10 * 60 * 1000; // 10 minutes

// Default fallback words (used if DB has none)
const DEFAULT_WORDS = [
  '傻逼', '操你', '去死', '滚蛋',
  '废物', '垃圾', '妈的', '尼玛',
  '脑残', '白痴',
];

function getWords() {
  const now = Date.now();
  if (_words !== null && (now - _lastFetch) < CACHE_TTL) {
    return _words;
  }

  try {
    const rows = db.prepare('SELECT word FROM sensitive_words ORDER BY id').all();
    if (rows.length > 0) {
      _words = rows.map(r => r.word);
    } else {
      // Seed default words into DB
      const insert = db.prepare('INSERT OR IGNORE INTO sensitive_words (word) VALUES (?)');
      for (const w of DEFAULT_WORDS) {
        insert.run(w);
      }
      _words = [...DEFAULT_WORDS];
    }
  } catch (_) {
    _words = [...DEFAULT_WORDS];
  }
  _lastFetch = now;
  return _words;
}

function containsSensitive(text) {
  const words = getWords();
  const lower = text.toLowerCase();
  return words.some(w => lower.includes(w.toLowerCase()));
}

function invalidateCache() {
  _words = null;
  _lastFetch = 0;
}

module.exports = { getWords, containsSensitive, invalidateCache };
