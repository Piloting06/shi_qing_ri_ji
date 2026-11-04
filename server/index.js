require('dotenv').config();
const express = require('express');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const cors = require('cors');
const { init: initDb, db } = require('./db');
const { sendCapsuleReminder } = require('./mail');

const app = express();
const PORT = process.env.PORT || 3001;

async function start() {
  await initDb();

  app.use(helmet());

  // 前面是 nginx 反代：信任 1 层代理，让限流按用户真实 IP 计数
  // （否则所有用户共享 nginx 内网 IP 的同一个限流桶，限流形同虚设）
  app.set('trust proxy', 1);

  // CORS 收紧：App 端不走浏览器 CORS，仅需放行官网落地页与本机开发调试
  const allowedOrigins = [
    'https://sqrj.hyfnoir.click',
    'https://xqrj.glxgo.xin',
    'http://localhost:3000',
    'http://127.0.0.1:3000',
  ];
  app.use(
    cors({
      origin(origin, cb) {
        if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
        cb(null, false);
      },
      credentials: true,
    })
  );
  app.use(express.json());

  const registerLimiter = rateLimit({ windowMs: 60000, max: 3, message: { message: '注册太频繁，请稍后再试' } });
  const loginLimiter = rateLimit({ windowMs: 60000, max: 10, message: { message: '登录太频繁，请稍后再试' } });


  app.use('/api/auth/register', registerLimiter);
  app.use('/api/auth/login', loginLimiter);
  app.use('/api/auth', require('./routes/auth'));
  app.use('/api/weather', require('./routes/weather'));
  app.use('/api/mood', require('./routes/mood'));
  app.use('/api/checkin', require('./routes/checkin'));
  app.use('/api/friends', require('./routes/friends'));
  app.use('/api/treehole', require('./routes/treehole'));
  app.use('/api/capsule', require('./routes/capsule'));
app.use('/api/admin', require('./routes/admin'));
app.use('/api/city', require('./routes/city'));
app.use('/api/feedback', require('./routes/feedback'));

// Admin panel static files
app.use('/admin', express.static(require('path').join(__dirname, 'admin')));
app.get('/admin', (_req, res) => res.sendFile(require('path').join(__dirname, 'admin', 'index.html')));

  app.get('/api/health', (_, res) => res.json({ status: 'ok', time: new Date().toISOString() }));

  // 落地页（卡片二维码指向根路径）+ 安装包下载，见 routes/landing.js
  app.use(require('./routes/landing'));

  app.use((err, _req, res, _next) => {
    console.error(err);
    res.status(500).json({ message: '服务器内部错误' });
  });

  app.listen(PORT, () => {
    console.log(`心晴日记 API running on port ${PORT}`);
  });

  // ── 胶囊到期邮件提醒（每小时检查一次）──
  function cstDate() {
    return new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 10);
  }

  async function checkCapsuleReminders() {
    try {
      const today = cstDate();
      const capsules = db.prepare(`
        SELECT tc.id, tc.open_date, tc.content, u.email
        FROM time_capsules tc
        JOIN users u ON tc.user_id = u.id
        WHERE tc.is_opened = 0
          AND tc.email_notified = 0
          AND tc.open_date <= ?
          AND u.email IS NOT NULL
          AND u.email != ''
          AND u.is_active = 1
      `).all(today);

      if (capsules.length === 0) return;

      console.log(`[CapsuleMail] 发现 ${capsules.length} 封到期胶囊，开始发送邮件...`);

      for (const cap of capsules) {
        try {
          await sendCapsuleReminder(cap.email, cap.open_date, cap.content);
          db.prepare('UPDATE time_capsules SET email_notified = 1 WHERE id = ?').run(cap.id);
          console.log(`[CapsuleMail] 胶囊 #${cap.id} → ${cap.email} ✓`);
        } catch (err) {
          console.error(`[CapsuleMail] 胶囊 #${cap.id} 发送失败:`, err.message);
        }
      }
    } catch (err) {
      console.error('[CapsuleMail] 检查失败:', err.message);
    }
  }

  // 启动后 30 秒执行首次检查，之后每小时一次
  setTimeout(() => {
    checkCapsuleReminders();
    setInterval(checkCapsuleReminders, 60 * 60 * 1000);
  }, 30000);
}

start();
