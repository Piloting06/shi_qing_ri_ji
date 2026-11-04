#!/usr/bin/env node
/**
 * 后端安全与边界测试（隔离实例专用，和 smoke_test.js 一样拒跑生产）。
 * 每一项是一个「应该成立」的断言；失败 = 发现一个 bug。
 *   BASE=http://127.0.0.1:3997 DB_FILE=<隔离实例的 xinqingriji.db> node scripts/security_test.js
 */
const fs = require('fs');
const BASE = process.env.BASE || 'http://127.0.0.1:3997';
if (/xqrj\.glxgo\.xin|114\.55\.138\.55/.test(BASE) && process.env.SMOKE_ALLOW_PROD !== '1') {
  console.error('拒绝对生产环境跑安全测试');
  process.exit(2);
}

let passed = 0;
const bugs = [];
async function raw(method, path, { token, body, headers = {} } = {}) {
  const h = { ...headers };
  if (token) h.Authorization = `Bearer ${token}`;
  if (body !== undefined && !h['Content-Type']) h['Content-Type'] = 'application/json';
  const res = await fetch(BASE + path, { method, headers: h, body: typeof body === 'string' ? body : body === undefined ? undefined : JSON.stringify(body) });
  const text = await res.text();
  let data = text;
  try { data = JSON.parse(text); } catch (_) {}
  return { status: res.status, data, text, type: res.headers.get('content-type') || '' };
}
async function check(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    bugs.push(`${name}：${e.message}`);
    console.log(`  ✗ ${name} — ${e.message}`);
  }
}
const expect = (c, m) => { if (!c) throw new Error(m); };
const cstDate = (d = 0) => new Date(Date.now() + 8 * 3600e3 + d * 86400e3).toISOString().slice(0, 10);
const phone = () => '137' + String(Math.floor(Math.random() * 1e8)).padStart(8, '0');

async function register() {
  const u = { phone: phone(), password: 'pw123456' };
  const r = await raw('POST', '/api/auth/register', { body: u });
  if (r.status !== 200) throw new Error('注册失败 ' + r.status + ' ' + r.text.slice(0, 80));
  return { ...u, token: r.data.token };
}

(async () => {
  console.log(`安全与边界测试 → ${BASE}`);
  const A = await register();
  const B = await register();

  console.log('· 路径穿越 / 敏感文件');
  for (const p of ['/landing/../.env', '/landing/%2e%2e/.env', '/landing/..%2f.env', '/landing/..%2fdb.js', '/admin/..%2f.env', '/admin/%2e%2e/xinqingriji.db', '/.env', '/db.js', '/xinqingriji.db', '/landing/../index.js']) {
    await check(`拿不到 ${p}`, async () => {
      const r = await raw('GET', p);
      expect(!/JWT_SECRET|ALIBABA|require\(|SQLite format/.test(r.text), `泄露了文件内容（${r.status}）`);
    });
  }

  console.log('· 请求格式');
  await check('坏 JSON → 400 中文（不是 500）', async () => {
    const r = await raw('POST', '/api/auth/login', { body: '{bad json', headers: { 'Content-Type': 'application/json' } });
    expect(r.status === 400, `状态 ${r.status}：${r.text.slice(0, 80)}`);
  });
  await check('超大请求体 → 413（不是 500）', async () => {
    const r = await raw('POST', '/api/treehole', { token: A.token, body: { content: 'x'.repeat(300 * 1024) } });
    expect(r.status === 413, `状态 ${r.status}`);
  });
  await check('不存在的 /api 路径 → JSON 404', async () => {
    const r = await raw('GET', '/api/nope');
    expect(r.status === 404 && r.type.includes('json'), `状态 ${r.status} 类型 ${r.type}`);
  });

  console.log('· 鉴权');
  await check('伪造 alg=none 的 token 被拒', async () => {
    const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const fake = `${b64({ alg: 'none', typ: 'JWT' })}.${b64({ userId: 1 })}.`;
    const r = await raw('GET', '/api/mood/all', { token: fake });
    expect(r.status === 401, `状态 ${r.status}`);
  });
  await check('管理接口无 token → 401', async () => {
    const r = await raw('GET', '/api/admin/users');
    expect(r.status === 401 || r.status === 403, `状态 ${r.status}`);
  });
  await check('普通用户 token 访问管理接口被拒', async () => {
    const r = await raw('GET', '/api/admin/users', { token: A.token });
    expect(r.status === 401 || r.status === 403, `状态 ${r.status}`);
  });

  console.log('· 越权（IDOR）');
  await check('看不到非好友的心情', async () => {
    const meB = await raw('GET', '/api/auth/profile', { token: B.token });
    const idB = meB.data.id || meB.data.user?.id;
    const r = await raw('GET', `/api/friends/${idB || 2}/mood`, { token: A.token });
    expect(r.status === 403 || r.status === 400, `状态 ${r.status}`);
  });
  await check('删不了别人的树洞', async () => {
    await raw('POST', '/api/treehole', { token: B.token, body: { content: '这是 B 的一条。' } });
    const l = await raw('GET', '/api/treehole', { token: A.token });
    const mine = (l.data.messages || []).find((m) => String(m.content).includes('B 的一条'));
    const r = await raw('DELETE', `/api/treehole/${mine.id}`, { token: A.token });
    expect(r.status === 403 || r.status === 404, `状态 ${r.status}`);
  });
  await check('删不了别人的城市足迹', async () => {
    const c = await raw('POST', '/api/city/comments', { token: B.token, body: { city_code: 'suzhou', content: '平江路。' } });
    const r = await raw('DELETE', `/api/city/comments/${c.data.id}`, { token: A.token });
    expect(r.status === 403, `状态 ${r.status}`);
  });
  await check('删不了别人的胶囊', async () => {
    await raw('POST', '/api/capsule', { token: B.token, body: { content: 'B 的胶囊', open_date: cstDate(1) } });
    const l = await raw('GET', '/api/capsule/list', { token: B.token });
    const id = (l.data.capsules || l.data)[0].id;
    const r = await raw('DELETE', `/api/capsule/${id}`, { token: A.token });
    expect(r.status === 403 || r.status === 404, `状态 ${r.status}`);
  });
  await check('没成为好友不能给对方留纸条', async () => {
    const meB = await raw('GET', '/api/auth/profile', { token: B.token });
    const idB = meB.data.id || meB.data.user?.id || 2;
    const r = await raw('POST', `/api/friends/${idB}/note`, { token: A.token, body: { content: '你好' } });
    expect(r.status >= 400 && r.status < 500, `状态 ${r.status}`);
  });

  console.log('· 注入');
  await check('登录手机号 SQL 注入无效', async () => {
    const r = await raw('POST', '/api/auth/login', { body: { phone: "' OR 1=1 --", password: "' OR 1=1 --" } });
    expect(r.status >= 400 && r.status < 500 && !r.data.token, `状态 ${r.status}`);
  });
  await check('搜索参数注入无效', async () => {
    const r = await raw('GET', `/api/friends/search?q=${encodeURIComponent("1' OR '1'='1")}`, { token: A.token });
    expect(r.status === 400 || (r.status === 200 && (r.data.users || []).length === 0), `状态 ${r.status}`);
  });

  console.log('· 输入校验');
  await check('心情：非法 emotion_type 被拒', async () => {
    const r = await raw('POST', '/api/mood', { token: A.token, body: { date: cstDate(), emotion_type: 'abc' } });
    expect(r.status === 400, `收下了非法心情（${r.status}）`);
  });
  await check('心情：非法日期被拒', async () => {
    const r = await raw('POST', '/api/mood', { token: A.token, body: { date: '2026-13-45', emotion_type: 1 } });
    expect(r.status === 400, `收下了非法日期（${r.status}）`);
  });
  await check('心情：缺日期被拒', async () => {
    const r = await raw('POST', '/api/mood', { token: A.token, body: { emotion_type: 1 } });
    expect(r.status === 400, `状态 ${r.status}`);
  });
  await check('心情：正文有长度上限', async () => {
    const r = await raw('POST', '/api/mood', { token: A.token, body: { date: cstDate(), emotion_type: 1, notes: '字'.repeat(20000) } });
    expect(r.status === 400, `两万字也收下了（${r.status}）`);
  });
  await check('树洞：每人每天 3 条', async () => {
    const C = await register();
    let last;
    for (let i = 0; i < 4; i++) last = await raw('POST', '/api/treehole', { token: C.token, body: { content: `第 ${i + 1} 条` } });
    expect(last.status === 429, `第 4 条状态 ${last.status}`);
  });
  await check('改署名：空 / 超长被拒', async () => {
    const r1 = await raw('POST', '/api/auth/change-username', { token: A.token, body: { username: '   ' } });
    const r2 = await raw('POST', '/api/auth/change-username', { token: A.token, body: { username: '名'.repeat(200) } });
    expect(r1.status === 400 && r2.status === 400, `空 ${r1.status}，超长 ${r2.status}`);
  });

  console.log('· 验证码');
  await check('发送失败时不谎报「已发送」', async () => {
    // 隔离实例用的是假短信密钥，必然发不出去
    const r = await raw('POST', '/api/auth/send-sms-code', { body: { phone: '13900000001' } });
    expect(r.status !== 200, `密钥无效也回 200「${r.data.message}」`);
  });
  await check('短信验证码接口有频率限制（防短信轰炸）', async () => {
    let last;
    for (let i = 0; i < 6; i++) last = await raw('POST', '/api/auth/send-sms-code', { body: { phone: '13800000000' } });
    expect(last.status === 429, `连发 6 次都放行（最后一次 ${last.status}）`);
  });
  await check('邮箱验证码接口有频率限制', async () => {
    let last;
    for (let i = 0; i < 6; i++) last = await raw('POST', '/api/auth/send-email-code', { body: { email: 'nobody@example.com' } });
    expect(last.status === 429, `连发 6 次都放行（最后一次 ${last.status}）`);
  });
  if (process.env.DB_FILE && fs.existsSync(process.env.DB_FILE)) {
    await check('验证码不以明文落库', async () => {
      await new Promise((r) => setTimeout(r, 6000)); // 等防抖落盘
      const buf = fs.readFileSync(process.env.DB_FILE);
      const initSqlJs = require('sql.js');
      const SQL = await initSqlJs();
      const db = new SQL.Database(buf);
      const rows = db.exec("SELECT code FROM sms_codes ORDER BY rowid DESC LIMIT 3");
      const codes = rows[0]?.values.map((v) => String(v[0])) || [];
      expect(!codes.some((c) => /^\d{6}$/.test(c)), `明文验证码：${codes.join(', ')}`);
    });
  }

  console.log('· 管理后台');
  await check('管理后台页面对用户内容转义（防存储型 XSS）', async () => {
    const html = fs.readFileSync(require('path').join(__dirname, '..', 'admin', 'index.html'), 'utf8');
    const raws = [/'\+String\(m\.content\|\|''\)/, /'\+u\.username\+'/, /'\+c\.content/];
    const hit = raws.filter((re) => re.test(html));
    expect(hit.length === 0, `${hit.length} 处用户内容未转义直接拼进 innerHTML`);
  });

  console.log(`\n${passed} 项通过，${bugs.length} 个问题`);
  bugs.forEach((b) => console.log('  - ' + b));
  process.exit(bugs.length ? 1 : 0);
})().catch((e) => {
  console.error('测试中断：', e);
  process.exit(1);
});
