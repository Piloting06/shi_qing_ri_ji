#!/usr/bin/env node
/**
 * 后端冒烟测试：对一个「隔离实例」跑一遍主要链路（注册 → 心情 → 签到 → 胶囊 → 树洞 → 好友 → 城迹 → 落地页）。
 * 会真的注册用户、写数据，所以默认拒绝对生产地址运行。
 *
 * 用法（隔离实例：独立目录 + 空库 + 测试 JWT）：
 *   JWT_SECRET=test PORT=3997 DB_BACKUP_DIR=/tmp/x DB_BACKUP_DIR_EXTERNAL=/tmp/x node index.js &
 *   BASE=http://127.0.0.1:3997 node scripts/smoke_test.js
 */
const BASE = process.env.BASE || 'http://127.0.0.1:3997';
if (/xqrj\.glxgo\.xin|114\.55\.138\.55/.test(BASE) && process.env.SMOKE_ALLOW_PROD !== '1') {
  console.error('拒绝对生产环境跑冒烟测试（会注册用户、写数据）。确需如此请设 SMOKE_ALLOW_PROD=1');
  process.exit(2);
}

let passed = 0;
const failures = [];

async function call(method, path, { token, body } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers.Authorization = `Bearer ${token}`;
  const res = await fetch(BASE + path, { method, headers, body: body ? JSON.stringify(body) : undefined });
  const type = res.headers.get('content-type') || '';
  const data = type.includes('json') ? await res.json() : await res.text();
  return { status: res.status, data, type };
}

async function check(name, fn) {
  try {
    await fn();
    passed++;
    console.log(`  ✓ ${name}`);
  } catch (e) {
    failures.push(`${name}: ${e.message}`);
    console.log(`  ✗ ${name} — ${e.message}`);
  }
}

function expect(cond, msg) {
  if (!cond) throw new Error(msg);
}

function expectStatus(r, status) {
  expect(r.status === status, `期望 ${status}，实际 ${r.status} ${JSON.stringify(r.data).slice(0, 120)}`);
}

/** 错误响应必须是 { message: 中文 } */
function expectChineseError(r) {
  expect(r.data && typeof r.data.message === 'string' && /[一-鿿]/.test(r.data.message), `错误响应不是中文 message：${JSON.stringify(r.data)}`);
}

const cstDate = (offsetDays = 0) => new Date(Date.now() + 8 * 3600e3 + offsetDays * 86400e3).toISOString().slice(0, 10);
const phone = () => '139' + String(Math.floor(Math.random() * 1e8)).padStart(8, '0');

(async () => {
  console.log(`冒烟测试 → ${BASE}`);
  const A = { phone: phone(), password: 'test123456' };
  const B = { phone: phone(), password: 'test654321' };

  console.log('· 基础');
  await check('健康检查', async () => {
    const r = await call('GET', '/api/health');
    expectStatus(r, 200);
    expect(r.data.status === 'ok', '状态不是 ok');
  });
  await check('未登录访问受保护接口 → 401 中文', async () => {
    const r = await call('GET', '/api/mood/all');
    expectStatus(r, 401);
    expectChineseError(r);
  });
  await check('坏 token → 401', async () => {
    const r = await call('GET', '/api/mood/all', { token: 'not-a-token' });
    expectStatus(r, 401);
  });

  console.log('· 落地页');
  await check('根路径出落地页（扫卡片二维码）', async () => {
    const r = await call('GET', '/?from=card');
    expectStatus(r, 200);
    expect(r.type.includes('text/html') && r.data.includes('拾晴日记') && r.data.includes('/sqrj.apk'), '落地页内容不对');
  });
  await check('落地页脚本与纹理', async () => {
    for (const p of ['/landing/app.js', '/landing/paper.png', '/landing/branch.png']) {
      const r = await fetch(BASE + p);
      expect(r.status === 200, `${p} → ${r.status}`);
    }
  });
  await check('安装包：有则 200 下载，无则 404 中文', async () => {
    const r = await fetch(BASE + '/sqrj.apk', { method: 'HEAD' });
    expect([200, 404].includes(r.status), `状态 ${r.status}`);
    if (r.status === 200) expect((r.headers.get('content-type') || '').includes('android.package-archive'), '类型不是 APK');
  });

  console.log('· 账号');
  // 注册限流是每分钟 3 次：A、B、重复注册正好 3 次，第 4 次起应被限流
  await check('注册 A、B', async () => {
    for (const u of [A, B]) {
      const r = await call('POST', '/api/auth/register', { body: u });
      expectStatus(r, 200);
      expect(r.data.token, '没有 token');
      u.token = r.data.token;
    }
  });
  await check('重复注册 → 409', async () => {
    const r = await call('POST', '/api/auth/register', { body: A });
    expectStatus(r, 409);
    expectChineseError(r);
  });
  await check('注册限流：一分钟内第 4 次 → 429 中文', async () => {
    const r = await call('POST', '/api/auth/register', { body: { phone: '123', password: 'x' } });
    expectStatus(r, 429);
    expectChineseError(r);
  });
  await check('密码错误登录被拒', async () => {
    const r = await call('POST', '/api/auth/login', { body: { phone: A.phone, password: 'wrong-pass' } });
    expect(r.status >= 400 && r.status < 500, `状态 ${r.status}`);
    expectChineseError(r);
  });
  await check('登录成功', async () => {
    const r = await call('POST', '/api/auth/login', { body: { phone: A.phone, password: A.password } });
    expectStatus(r, 200);
    expect(r.data.token, '没有 token');
  });
  await check('个人资料', async () => {
    const r = await call('GET', '/api/auth/profile', { token: A.token });
    expectStatus(r, 200);
  });
  await check('改署名', async () => {
    const r = await call('POST', '/api/auth/change-username', { token: A.token, body: { username: '晚风' } });
    expectStatus(r, 200);
  });

  console.log('· 心情');
  let moodId;
  await check('写一条心情（含城市与天气码）', async () => {
    const r = await call('POST', '/api/mood', {
      token: A.token,
      body: { date: cstDate(), emotion_type: 7, emotion_tags: '', notes: '周末要去看外婆。', city: '杭州', weather_code: '61' },
    });
    expectStatus(r, 200);
    moodId = r.data.id;
    expect(moodId, '没有 id');
  });
  await check('同一天再写一条（一天可多条）', async () => {
    const r = await call('POST', '/api/mood', { token: A.token, body: { date: cstDate(), emotion_type: 2, notes: '晚上平静一些' } });
    expectStatus(r, 200);
  });
  await check('按日期取 / 取全部', async () => {
    const r1 = await call('GET', `/api/mood?date=${cstDate()}`, { token: A.token });
    expectStatus(r1, 200);
    const list = Array.isArray(r1.data) ? r1.data : r1.data.moods;
    expect(Array.isArray(list) && list.length >= 2, '当天应有两条');
    const r2 = await call('GET', '/api/mood/all', { token: A.token });
    expectStatus(r2, 200);
    expect(Array.isArray(r2.data.moods) && r2.data.moods.length >= 2, '全部列表不对');
  });
  await check('删别人的心情 → 404', async () => {
    const r = await call('DELETE', `/api/mood/${moodId}`, { token: B.token });
    expectStatus(r, 404);
  });

  console.log('· 签到');
  await check('签到幂等', async () => {
    const r1 = await call('POST', '/api/checkin', { token: A.token });
    expectStatus(r1, 200);
    const r2 = await call('POST', '/api/checkin', { token: A.token });
    expectStatus(r2, 200);
    expect(r2.data.consecutive_days === r1.data.consecutive_days, '重复签到改变了连续天数');
    const s = await call('GET', '/api/checkin/status', { token: A.token });
    expect(s.data.checked_in === true, '状态未显示已签到');
  });

  console.log('· 时光胶囊');
  let capsuleId;
  await check('日期早于今天 → 400', async () => {
    const r = await call('POST', '/api/capsule', { token: A.token, body: { content: '给以后', open_date: cstDate(-2) } });
    expectStatus(r, 400);
    expectChineseError(r);
  });
  await check('封一颗三天后的胶囊', async () => {
    const r = await call('POST', '/api/capsule', { token: A.token, body: { content: '三天后的我，你好。', open_date: cstDate(3) } });
    expectStatus(r, 200);
  });
  await check('同内容同日期不重复封', async () => {
    await call('POST', '/api/capsule', { token: A.token, body: { content: '三天后的我，你好。', open_date: cstDate(3) } });
    const r = await call('GET', '/api/capsule/list', { token: A.token });
    expectStatus(r, 200);
    const list = r.data.capsules || r.data;
    expect(Array.isArray(list) && list.length === 1, `应只有 1 颗，实际 ${Array.isArray(list) ? list.length : '?'}`);
    capsuleId = list[0].id;
  });
  await check('没到日子不能拆 → 403', async () => {
    const r = await call('GET', `/api/capsule/${capsuleId}`, { token: A.token });
    expectStatus(r, 403);
    expectChineseError(r);
  });
  await check('别人拿不到我的胶囊', async () => {
    const r = await call('GET', `/api/capsule/${capsuleId}`, { token: B.token });
    expect([403, 404].includes(r.status), `状态 ${r.status}`);
  });

  console.log('· 树洞');
  let holeId;
  await check('空内容 → 400', async () => {
    const r = await call('POST', '/api/treehole', { token: A.token, body: { content: '   ' } });
    expectStatus(r, 400);
  });
  await check('发一条，列表里能看到', async () => {
    const r = await call('POST', '/api/treehole', { token: A.token, body: { content: '下雨天，适合一个人听歌。' } });
    expectStatus(r, 200);
    const l = await call('GET', '/api/treehole', { token: B.token });
    expectStatus(l, 200);
    const hit = (l.data.messages || []).find((m) => String(m.content).includes('适合一个人听歌'));
    expect(hit, '列表里没有');
    holeId = hit.id;
  });
  await check('送抱抱：一次成功，重复 409', async () => {
    const r1 = await call('POST', `/api/treehole/${holeId}/interact`, { token: B.token, body: { interaction_type: 'cloud_hug' } });
    expectStatus(r1, 200);
    const r2 = await call('POST', `/api/treehole/${holeId}/interact`, { token: B.token, body: { interaction_type: 'cloud_hug' } });
    expectStatus(r2, 409);
  });
  await check('回应一句', async () => {
    const r = await call('POST', `/api/treehole/${holeId}/comments`, { token: B.token, body: { content: '我也喜欢下雨天。' } });
    expectStatus(r, 200);
    const c = await call('GET', `/api/treehole/${holeId}/comments`, { token: A.token });
    expectStatus(c, 200);
  });

  console.log('· 好友');
  let requestId;
  await check('不能加自己', async () => {
    const r = await call('POST', '/api/friends/add', { token: A.token, body: { phone: A.phone } });
    expectStatus(r, 400);
  });
  await check('A 加 B，重复申请 409', async () => {
    const r = await call('POST', '/api/friends/add', { token: A.token, body: { phone: B.phone } });
    expectStatus(r, 200);
    const r2 = await call('POST', '/api/friends/add', { token: A.token, body: { phone: B.phone } });
    expectStatus(r2, 409);
  });
  await check('B 收到请求并同意（可看心情）', async () => {
    const r = await call('GET', '/api/friends/requests', { token: B.token });
    expectStatus(r, 200);
    const req = (r.data.requests || r.data)[0];
    expect(req, '没有请求');
    requestId = req.id;
    const ok = await call('POST', '/api/friends/respond', { token: B.token, body: { id: requestId, status: 1, can_view_mood: true } });
    expectStatus(ok, 200);
  });
  await check('双方好友列表', async () => {
    for (const u of [A, B]) {
      const r = await call('GET', '/api/friends/list', { token: u.token });
      expectStatus(r, 200);
      expect((r.data.friends || []).length === 1, '好友数不对');
    }
  });

  console.log('· 城迹与反馈');
  await check('城市统计 / 心晴榜', async () => {
    expectStatus(await call('GET', '/api/city/stats', { token: A.token }), 200);
    expectStatus(await call('GET', '/api/city/moodboard', { token: A.token }), 200);
  });
  await check('留足迹：同城每天两条，第三条 → 429', async () => {
    for (const text of ['西湖边下小雨。', '傍晚停了。']) {
      expectStatus(await call('POST', '/api/city/comments', { token: A.token, body: { city_code: 'hangzhou', content: text } }), 200);
    }
    const r3 = await call('POST', '/api/city/comments', { token: A.token, body: { city_code: 'hangzhou', content: '再来一句' } });
    expectStatus(r3, 429);
    expectChineseError(r3);
    const l = await call('GET', '/api/city/comments?city=hangzhou', { token: B.token });
    expectStatus(l, 200);
  });
  await check('反馈空内容 → 400', async () => {
    const r = await call('POST', '/api/feedback', { token: A.token, body: { content: '' } });
    expectStatus(r, 400);
    expectChineseError(r);
  });

  console.log('· 收尾');
  await check('注销 B 后 B 的 token 失效', async () => {
    const r = await call('POST', '/api/auth/delete-account', { token: B.token, body: { password: B.password } });
    expect([200, 400].includes(r.status), `状态 ${r.status}`);
    if (r.status === 200) {
      const after = await call('GET', '/api/mood/all', { token: B.token });
      expectStatus(after, 401);
    }
  });

  console.log(`\n${passed} 项通过，${failures.length} 项失败`);
  if (failures.length) {
    failures.forEach((f) => console.log('  - ' + f));
    process.exit(1);
  }
})().catch((e) => {
  console.error('冒烟测试中断：', e);
  process.exit(1);
});
