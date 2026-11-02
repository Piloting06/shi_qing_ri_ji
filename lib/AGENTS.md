# AGENTS.md — lib/（Flutter 客户端）

Provider 状态管理；设计系统在 `theme/`；入口 `main.dart`。

## 质量门禁（提交前必过）

- `flutter analyze` **0 issue**（含 warning/info，这是历史基线，不许回退）。
- `flutter test` 全过；纯逻辑（统计/生成器/映射）新增或修改时同步补 `test/` 用例。

## 模块地图

| 路径 | 职责 |
|---|---|
| `api/` | 按域拆分的 API 模块；`api_base.dart` 的 `baseUrl` 是唯一地址来源（现为 `https://xqrj.glxgo.xin/api`） |
| `constants/mood.dart` | 心情体系唯一来源：emoji/label/颜色/标签（8 种，score 1–8），改心情先改这里 |
| `stores/` | AppState（用户/数据）、ThemeState（主题）、MapState（城迹） |
| `theme/` | 颜色 Token/字体/装饰/纸纹——页面禁止硬编码色值，一律走主题 token |
| `widgets/mood_card/` | 卡片模板（见下） |
| `widgets/` | 通用组件：StaggerIn（错落入场）、PressableScale（按压缩放）、XqEmptyState、XqToast… |
| `utils/` | `solar_term_utils`（节气）、`weather_utils`（码→文案）、`geo_utils`（城市匹配）、`mood_insight` |

## 卡片模板（lib/widgets/mood_card/）

- 架构：`MoodCardData`（数据包）+ `mood_card_registry.dart`（注册表）。**新增模板 = 写一个 `Widget Function(MoodCardData)` builder + 注册表加一条 `MoodCardTemplateSpec`**，不要在 mood_card_maker 里堆 if/else。
- 模板高度自适应：固定尺寸写 `data.height`（竖版 216 / 方图≈卡宽），正文字号乘 `data.bodyScale`。
- 晴收集模板：配色走 `paletteFor(weather)`，天气可被 `_weatherOverride` 覆盖（用户编辑权，别移除）。
- 导出：RepaintBoundary `_repaintKey` 只挂在当前模板上（`i == _templateIndex`），pixelRatio 3.0；保存后经 `CardAlbumStore.archive` 进卡片册。

## 已踩过的坑（禁止重犯）

1. **巨石页面拆分用 part + extension**：profile_page 模式——主文件持有 State，方法块放 `profile_page_*.dart` 的 `extension on _ProfilePageState`；extension 里调 `setState` 会触发 protected 告警，走主类的 `_setState` 转发；静态常量引用要加 `_ProfilePageState.` 前缀。
2. **showModalBottomSheet 里的输入框**键盘遮挡：改用 `showDialog + AlertDialog + StatefulBuilder`。
3. **Tab 切换页面的 controller**：`dispose()` 只调一次；TextEditingController 在 build 里 new 会导致光标跳动（initState 持有）。
4. **树洞底部输入区**放 `Scaffold.bottomNavigationBar`，自动避键盘。
5. **定位缓存版本**：`loc_cache_ver`（home_page）用于污染缓存整体失效，改定位逻辑时递增。
6. **本地通知**：胶囊提醒 ID `700000 + capsuleId`、目标日 9:08、payload `{"type":"capsule","capsuleId":N}`；Android 14+ 先查 `canScheduleExactNotifications` 再降级 inexact。
7. **主框架 4 Tab**：主框架 4 Tab（天气/心情/城迹/我的）。跨 Tab 跳转用 `MainScaffold.switchToTab(context, i)`，不要自己 Navigator 堆栈。
