// 初始化管理员账号
// 用法: node server/seed_admin.js <username> <password>
const bcrypt = require('bcryptjs');
const { init, db } = require('./db');

async function main() {
  await init();

  const username = process.argv[2];
  const password = process.argv[3];
  if (!username || !password) {
    console.error('用法: node server/seed_admin.js <username> <password>');
    process.exit(1);
  }

  const existing = db.prepare('SELECT id FROM admin_users WHERE username = ?').get(username);
  if (existing) {
    console.log(`管理员 ${username} 已存在，跳过创建`);
    process.exit(0);
  }

  const hash = bcrypt.hashSync(password, 10);
  db.prepare('INSERT INTO admin_users (username, password_hash) VALUES (?,?)').run(username, hash);
  console.log(`管理员 ${username} 创建成功`);
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
