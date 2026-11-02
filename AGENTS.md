# AGENTS.md — 拾晴日记

天气×心情手账 App（Flutter + Node/Express + SQLite）。仓库：`Piloting06/shi_qing_ri_ji`。

## 红线

- 质量门禁：提交前 `flutter analyze` 0 issue、`flutter test` 全过；新逻辑必须带单元测试。
- 凭据/数据库/用户数据不进 Git（`.env`、`*.db`、`artifacts/` 已忽略）。运维凭据只在 `artifacts/ops.md`（本地）。
- 后端不开新端口、不改既有挂载点、不换数据库引擎（共享服务器历史约定）。
- 用户已批准的业务决定记录在 `docs/scope.md`；推翻需用户新决定，不改写旧记录。
- `docs/adr/` 冻结正文；推翻决定用新编号 + Superseded 双向链接。
- 发版：`pubspec.yaml` 版本号递增 → 构建 → `拾晴日记_v<版本>_<日期>.apk` 命名。

## 模块路由

| 目录 | 职责与局部约定 | 入口 |
|---|---|---|
| `lib/` | Flutter 客户端：页面/组件/主题/状态 | `lib/AGENTS.md` |
| `lib/widgets/mood_card/` | 卡片模板（新增模板 = builder + 注册一行） | `lib/AGENTS.md` |
| `server/` | Express 后端：路由/db/备份/后台 | `server/AGENTS.md` |
| `docs/status.md` | **当前版本/部署/未验证清单的唯一来源** | — |
| `docs/scope.md` | 已批准业务规则（带日期与决定人） | — |
| `docs/adr/` | 架构决定（追加式，Accepted 后冻结） | — |
| `CONTEXT.md` | 业务术语表 | — |
| `sqrj-landing/` | 官网落地页（Next.js 静态导出，独立构建） | — |

## 事实来源约定

- 运行状态、版本、未验证事项看 `docs/status.md`，不问历史文档。
- 表结构与 API 以 `server/db.js`、`server/routes/` 源码为准，任何文档不复制定义。
- 运维凭据与面板地址在 `artifacts/ops.md`（git 忽略）。
- 汇报遵守交付事实分层：实现/验证/上线/待办四项，未验证如实写"未验证"。

## 工作流

1. 动手前读本文件 + 对应模块 AGENTS.md + `docs/status.md`。
2. 部署与运维命令见 `artifacts/ops.md`（服务器 SSH 别名 `xqrj`）。
3. 改跨模块契约/换依赖/动数据模型/动安全基线 → 写新 ADR。
