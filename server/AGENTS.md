# AGENTS.md — server/（Express 后端）

Express 5 + helmet + cors + express-rate-limit + sql.js。端口 3001，PM2 进程 `xinqingriji`，nginx 反代 `https://xqrj.glxgo.xin`（历史备用：IP:8888）。

## db.js（数据层）

- sql.js 包装器模拟 better-sqlite3 API：`db.prepare(sql).run/get/all(...params)`；`run` 返回 `{lastInsertRowid, changes}`。
- **持久化是防抖合并 + 原子写**（脏标记 → 500ms 防抖/上限 5s → 临时文件 fsync 后 rename）。不要改回"每次写操作直接写盘"；`saveDb()` 仅用于需要立即落盘的场景。
- 退出信号（SIGINT/SIGTERM/uncaughtException）自动强制落盘。
- 每日双备份：`server/backups/`（保留 14 份）+ `DB_BACKUP_DIR_EXTERNAL`（默认 `/root/db_backup`）。恢复用 `scripts/restore.js`（先 `pm2 stop`，恢复前自动留底）。
- 迁移模式：`init()` 内 `PRAGMA table_info` 检查缺列后 `ALTER TABLE`（users.email、moods.city 即此模式），新列照此办理。

## 约定与不变量

- **CST 时间**：日期判断用 `cstDate()`（UTC+8），禁止 `new Date().toISOString()` 直接取日期。SQLite `datetime('now')` 存 UTC。
- **错误响应**：`{ "message": "中文描述" }`；400 参数/业务拒绝、401 未登录、403 无权（胶囊未到期/好友授权过期）、404、409 冲突、429 限频、500 兜底。
- **鉴权**：`middleware/auth.js`，Bearer token（JWT 30 天），`req.userId` 注入，校验 `is_active=1 AND deleted_at IS NULL`。
- **幂等/防重**：签到按 `user_id+date`；胶囊按 `user_id+content+open_date+is_opened=0`；树洞每人每天 3 条（CST）；互动/点赞靠 UNIQUE 约束。
- **好友关系双向查**：`WHERE (user_id=A AND friend_id=B) OR (user_id=B AND friend_id=A)`。
- **心情记录**：INSERT 语义（一天可多条），写入 `city` + `weather_code`（城迹榜/心晴签/年度报告的数据源，勿去掉）。
- **新增路由**：只新增 `routes/xxx.js` 并在 `index.js` 挂载到 `/api/` 下；不开新端口。唯一例外是 `routes/landing.js`：根路径 `/` 出落地页（分享卡片二维码指向 `/?from=card`），`/sqrj.apk` 下载安装包，静态资源在 `server/landing/`。
- **安全基线**：`trust proxy 1`（限流按真实 IP）；CORS 白名单在 `index.js`（加域名改那里）；全部 SQL 参数绑定；`sms_codes`（sha256(目标:码)）/密码只存哈希；发码 IP 十分钟 5 次 + 同号一分钟 1 次，校验 IP 十分钟 20 次；发码失败如实回 502。
- **管理员 token**：签发带 `role: 'admin'`，`adminAuth` 校验 role 且账号仍在 `admin_users`（未配 `ADMIN_JWT_SECRET` 时与用户 token 同钥，不校验 role 普通用户可进后台）。后台页面拼 innerHTML 一律 `esc()`。
- **天气缓存**：`routes/weather.js` 内存缓存 10 分钟；`/location` 必须把 `X-Forwarded-For`/`X-Real-IP` 的客户端 IP 放进 ip-api **路径**（`/json/{ip}`），内网 IP 返回未知。

## 测试

`npm run smoke`（`scripts/smoke_test.js`）：对隔离实例跑 35 项主链路（账号 / 心情 / 签到 / 胶囊 / 树洞 / 好友 / 城迹 / 落地页 / 限流 / 中文报错）。会注册用户、写数据，默认拒绝对生产地址运行。隔离实例 = 拷一份 server 目录（不带 `*.db`、`.env`）+ 空库 + 测试用环境变量：

```
JWT_SECRET=test PORT=3997 DB_BACKUP_DIR=/tmp/x DB_BACKUP_DIR_EXTERNAL=/tmp/x ALIBABA_ACCESS_KEY_ID=dummy ALIBABA_ACCESS_KEY_SECRET=dummy node index.js &
BASE=http://127.0.0.1:3997 npm run smoke
```

`npm run security`（`scripts/security_test.js`）：34 项安全与边界（路径穿越、坏 JSON / 超大请求体、伪造 token、普通用户进后台、越权删改、SQL 注入、输入校验、验证码限频与哈希、后台 XSS 转义）。两套共用注册限流（每分钟 3 次），之间重启一次实例。

部署前两套都跑一遍。

## 部署

运维凭据、SSH 别名、发布步骤见 `artifacts/ops.md`（本地，git 忽略）。改动后 `pm2 restart xinqingriji` + 内外网 health 双验证；涉 db.js 需确认备份目录出现新文件。**每次发版**把新 APK 传到服务器 `server/landing/sqrj.apk`（不进 Git），并改 `landing/index.html` 里的版本号与大小。

## 表结构

以 `db.js` 的 `init()` 建表语句为唯一来源，文档不复制定义（历史文档中的 diary 表已随功能删除失效）。
