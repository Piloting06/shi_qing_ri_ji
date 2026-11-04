// 落地页：分享卡片上的二维码 / 链接指向根路径（https://xqrj.glxgo.xin/?from=card）。
// 页面、纹理、安装包都放 server/landing/；安装包（sqrj.apk）不进 Git，每次发版替换。
// 这是唯一挂在 /api 之外的业务路由：根路径以前直接 404（「Cannot GET /」），扫码的人什么也看不到。
const path = require('path');
const fs = require('fs');
const express = require('express');

const router = express.Router();
const dir = path.join(__dirname, '..', 'landing');

router.use('/landing', express.static(dir, { index: false, maxAge: '1h' }));

router.get('/', (_req, res) => {
  res.set('Cache-Control', 'no-cache');
  res.sendFile(path.join(dir, 'index.html'));
});

router.get('/sqrj.apk', (_req, res) => {
  const file = path.join(dir, 'sqrj.apk');
  if (!fs.existsSync(file)) {
    return res.status(404).json({ message: '安装包正在更新，过一会儿再来' });
  }
  res.set('Content-Type', 'application/vnd.android.package-archive');
  res.download(file, 'shiqingriji.apk');
});

module.exports = router;
