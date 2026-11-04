# 状态（唯一来源 · 替换事实，不追加日志）

> 最后更新：2026-11-03

## 版本与构建

| 项 | 值 |
|---|---|
| 当前版本 | **v2.17.4+37（素笺提质 P0–P4 完成，P5 收尾中）** |
| 最新 APK | 项目根目录最新的 `拾晴日记_v2.17.4_p4_*.apk` |
| 仓库 | `github.com/Piloting06/shi_qing_ri_ji`（2026-11-02 由 xin_qing_ri_ji 改名） |
| 分支 | `master`（v2.15.1 基线）← `feat/jiangnan-visual`（v2.16.0，PR#1）← `fix/p0-visual`（PR#2）← `feat/p1-typography`（PR#3）← `feat/p2-components`（PR#4）← `feat/p3-sample`（PR#5，含 P4 铺开）——**堆叠 PR，按序合并** |

## 已上线（生产验证）

- 服务端：`xqrj.glxgo.xin`（PM2 `xinqingriji`:3001 + nginx），v2.5.0 服务端优化已部署（防抖落盘/双备份/trust proxy/CORS 白名单）
- v2.12.0 服务端：moods.city 列迁移完成、`/city/moodboard` 上线、POST /mood 写入城市+天气码
- 每日数据库双备份运行中（`server/backups/` + `/root/db_backup/`）

## 素笺提质 P0–P4（本分支已实现，待真机验证）

- **P0**：黑山修复（ridge 漏上色）+ 黄金基准回归测试（昼/夜）；毛玻璃胶囊导航 → 贴底通栏（surface+1px线+56px）；对比度 Token（textTertiary/controlBorder/gold/warning/success/夜seal）
- **P1**：SerifSC 宋体子集打包（产品文案 1801 字，500/600 两档共 93KB）；字号七级收敛（display28/title20/section16/body15/reading17/caption13/micro12）；全库去 w700+
- **P2**：XqIcon 自绘线性图标 14 枚（导航已用）；XqButton/XqTag/XqSeal/XqPageHeader/XqCard 组件库；Toast 统一（SnackBar 清零：双击退出/胶囊）
- **P3**：首页减法落地（天气/那年今日无边框一行、山水 35%、文字不压山）；心情页保存条吸底；登录/注册去金卡改朱砂小印+宋体名，切换文字+细线，输入框去框内图标
- **P4**：GlowWrap 重写为纯手势包装（光晕/波纹/呼吸全产品清零）；心情釉色化八色；烟雨色板（瓦白/黛青/墨灰/暗木）；文案语域统一（去感叹号/卖萌/技术拼接）

## 待办

- P5：6 主题回归（暖笺/黛笺/青笺/藕笺切换与素笺深浅）、无障碍 Semantics 补齐、真机全量验收
- 宋体子集扩字（用户名生僻字时系统回退，可接受）、自绘图标套件扩充、故事跨设备同步
- 年度报告（Q4，节气章引擎已就绪）

## 质量基线

- `flutter analyze`：0 issue ｜ `flutter test`：13 项全过（含烟雨场景黄金基准昼/夜）
- 服务端 API：隔离实例 36 项链路验证通过；生产库每日双备份运行中
