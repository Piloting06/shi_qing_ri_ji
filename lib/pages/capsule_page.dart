import 'package:flutter/foundation.dart';
import '../widgets/ink_bloom.dart';
import '../widgets/xq_empty_state.dart';
import '../widgets/xq_toast.dart';
import 'package:flutter/material.dart';
import '../widgets/weather_sky.dart' show chineseNumber;
import '../widgets/xq/xq_kit.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../utils/helpers.dart';
import '../utils/time_utils.dart';
import '../theme/xq_decorations.dart';

import '../api/api_client.dart';
import '../services/notification_service.dart';
import '../stores/theme_state.dart';
import '../theme/xq_typography.dart';
import '../widgets/ink_writing_loader.dart';

class _BrandStep {
  final XqIcons icon;
  final String title;
  final String desc;
  const _BrandStep(this.icon, this.title, this.desc);
}

class _BrandGuide {
  final String name;
  final String system;
  final XqIcons icon;
  final List<_BrandStep> steps;
  const _BrandGuide({required this.name, required this.system, required this.icon, required this.steps});
}

class CapsulePage extends StatefulWidget {
  final int? initialCapsuleId;

  const CapsulePage({super.key, this.initialCapsuleId});

  @override
  State<CapsulePage> createState() => _CapsulePageState();
}

class _CapsulePageState extends State<CapsulePage> {
  List<Map<String, dynamic>> _capsules = [];
  bool _loading = true;
  bool _creating = false;
  bool _initialHandled = false;
  String? _error;
  final _contentCtrl = TextEditingController();
  int _days = 3;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final data = await Api.getCapsuleList();
      if (mounted) {
        setState(() {
          _capsules = List<Map<String, dynamic>>.from(data['capsules'] ?? []);
          _loading = false;
        });
      }
      _maybeOpenInitialCapsule();
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = '胶囊加载失败，请重试';
        });
      }
    }
  }

  void _maybeOpenInitialCapsule() {
    if (_initialHandled || widget.initialCapsuleId == null || !mounted) return;
    _initialHandled = true;
    Map<String, dynamic>? capsule;
    for (final item in _capsules) {
      if (readInt(item['id']) == widget.initialCapsuleId) {
        capsule = item;
        break;
      }
    }
    if (capsule == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没找到这颗胶囊')),
      );
      return;
    }
    final targetCapsule = capsule;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _open(targetCapsule, fromReminder: true);
      }
    });
  }

  Future<void> _create() async {
    final text = _contentCtrl.text.trim();
    if (text.isEmpty || _creating) return;
    if (text.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('内容最多 500 字')));
      return;
    }

    setState(() => _creating = true);
    final openDate = DateTime.now().add(Duration(days: _days));
    final dateStr = DateFormat('yyyy-MM-dd').format(openDate);
    try {
      final data = await Api.createCapsule(text, dateStr);
      final capsuleId = readInt(data['id']);
      if (capsuleId != null) {
        await NotificationService.scheduleCapsuleReminder(
          capsuleId: capsuleId,
          openDate: data['open_date']?.toString() ?? dateStr,
          preview: _notificationPreview(text),
        );
      }
      _contentCtrl.clear();
      HapticFeedback.mediumImpact();
      if (mounted) {
        final msg = _days == 1 ? '胶囊已封存，明天会提醒你' : '胶囊已封存，到时会提醒你';
        XqToast.success(context, msg);
      }
      await _load();
      // 封存成功后，弹出品牌引导（帮助用户确保通知能收到）
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 600));
        await _showNotificationGuide();
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('创建失败，请稍后重试')));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _open(
    Map<String, dynamic> capsule, {
    bool fromReminder = false,
  }) async {
    final id = readInt(capsule['id']);
    if (id == null) return;
    if (_isOpened(capsule)) {
      _showContent(capsule, fromReminder: fromReminder);
      return;
    }
    final openDate = DateTime.tryParse(capsule['open_date']?.toString() ?? '');
    if (openDate != null && openDate.isAfter(_today())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${DateFormat('M月d日').format(openDate)} 才能打开')),
      );
      return;
    }
    try {
      HapticFeedback.heavyImpact();
      final data = await Api.openCapsule(id);
      if (mounted) {
        // 全产品唯一的仪式动效：墨迹晕开（系统减弱动效时自动跳过）
        final theme = Theme.of(context);
        final reduced = MediaQuery.of(context).disableAnimations;
        await InkBloom.play(
          context,
          ink: theme.textTheme.bodyLarge?.color ?? theme.colorScheme.onSurface,
          reducedMotion: reduced,
        );
        if (mounted) {
          _showContent(Map<String, dynamic>.from(data), fromReminder: fromReminder);
          await _load();
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 401) return;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        XqToast.error(context, '打开失败，请稍后再试');
      }
    }
  }

  static const _brands = [
    _BrandGuide(
      name: 'OPPO / 一加 / realme',
      system: 'ColorOS',
      icon: XqIcons.phone,
      steps: [
        _BrandStep(XqIcons.logout, '自启动', '设置 → 应用 → 应用管理 → 拾晴日记 → 打开「自启动」'),
        _BrandStep(XqIcons.battery, '电池优化', '设置 → 应用 → 应用管理 → 拾晴日记 → 耗电保护 → 选择「无限制」'),
        _BrandStep(XqIcons.bell, '通知', '设置 → 通知与状态栏 → 拾晴日记 → 允许通知'),
      ],
    ),
    _BrandGuide(
      name: '华为 / 荣耀',
      system: 'HarmonyOS',
      icon: XqIcons.spark,
      steps: [
        _BrandStep(XqIcons.logout, '自启动', '手机管家 → 应用启动管理 → 拾晴日记 → 关闭「自动管理」→ 全部手动开启'),
        _BrandStep(XqIcons.battery, '电池优化', '设置 → 应用 → 拾晴日记 → 耗电详情 → 启动管理 → 手动管理'),
        _BrandStep(XqIcons.bell, '通知', '设置 → 通知和状态栏 → 拾晴日记 → 允许通知'),
      ],
    ),
    _BrandGuide(
      name: '小米 / Redmi',
      system: 'HyperOS / MIUI',
      icon: XqIcons.spark,
      steps: [
        _BrandStep(XqIcons.logout, '自启动', '设置 → 应用设置 → 拾晴日记 → 打开「自启动」'),
        _BrandStep(XqIcons.battery, '电池优化', '设置 → 应用设置 → 拾晴日记 → 省电策略 → 选择「无限制」'),
        _BrandStep(XqIcons.bell, '通知', '设置 → 通知管理 → 拾晴日记 → 允许通知'),
      ],
    ),
    _BrandGuide(
      name: 'vivo / iQOO',
      system: 'Funtouch OS / OriginOS',
      icon: XqIcons.spark,
      steps: [
        _BrandStep(XqIcons.logout, '自启动', 'i管家 → 应用管理 → 权限管理 → 拾晴日记 → 打开「自启动」'),
        _BrandStep(XqIcons.battery, '电池优化', '设置 → 应用 → 拾晴日记 → 电池 → 打开「允许后台高耗电」'),
        _BrandStep(XqIcons.bell, '通知', '设置 → 通知 → 拾晴日记 → 允许通知'),
      ],
    ),
    _BrandGuide(
      name: '其他 Android 手机',
      system: '通用设置',
      icon: XqIcons.tune,
      steps: [
        _BrandStep(XqIcons.logout, '自启动', '安全中心或手机管家 → 应用管理 → 拾晴日记 → 允许自启动'),
        _BrandStep(XqIcons.battery, '电池优化', '设置 → 应用 → 拾晴日记 → 电池或耗电 → 设为不限制'),
        _BrandStep(XqIcons.bell, '通知', '设置 → 通知 → 拾晴日记 → 允许通知'),
      ],
    ),
  ];

  Future<void> _showNotificationGuide() async {
    final theme = context.read<ThemeState>();
    final pageCtrl = PageController();
    var currentPage = 0;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.borderColor, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 12),
                    Text('让提醒准时到', style: XqTypography.headlineMedium.copyWith(color: theme.textPrimary)),
                    const SizedBox(height: 6),
                    Text('左右滑，找你的手机品牌', style: TextStyle(color: theme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 14),
                    // 品牌指示器
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_brands.length, (i) =>
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: currentPage == i ? 20.0 : 6.0,
                          height: 6.0,
                          decoration: BoxDecoration(
                            color: currentPage == i ? theme.accentColor : theme.borderColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // PageView — 用 SizedBox 给固定高度
                    SizedBox(
                      height: 320,
                      child: PageView.builder(
                        controller: pageCtrl,
                        onPageChanged: (i) => setState(() => currentPage = i),
                        itemCount: _brands.length,
                        itemBuilder: (_, i) {
                          final b = _brands[i];
                          return SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: theme.accentColor.withAlpha(18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: XqIcon(b.icon, color: theme.accentColor, size: 26),
                                ),
                                const SizedBox(height: 8),
                                Text(b.name, style: TextStyle(color: theme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(b.system, style: TextStyle(color: theme.textTertiary, fontSize: 12)),
                                const SizedBox(height: 20),
                                ...b.steps.map((s) => Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: theme.accentColor.withAlpha(14),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: XqIcon(s.icon, color: theme.accentColor, size: 18),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(s.title, style: TextStyle(color: theme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                            const SizedBox(height: 3),
                                            Text(s.desc, style: TextStyle(color: theme.textSecondary, fontSize: 12, height: 1.4)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    // 左右箭头导航
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: currentPage > 0 ? () => pageCtrl.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
                          icon: XqIcon(XqIcons.back, size: 18, color: currentPage > 0 ? theme.accentColor : theme.borderColor),
                        ),
                        const SizedBox(width: 24),
                        Text('${currentPage + 1} / ${_brands.length}', style: TextStyle(color: theme.textTertiary, fontSize: 12)),
                        const SizedBox(width: 24),
                        IconButton(
                          onPressed: currentPage < _brands.length - 1 ? () => pageCtrl.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic) : null,
                          icon: XqIcon(XqIcons.chevronRight, size: 18, color: currentPage < _brands.length - 1 ? theme.accentColor : theme.borderColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const XqIcon(XqIcons.check, size: 18),
                          label: const Text('设置好了'),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.accentColor,
                            foregroundColor: theme.textOnAccent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    pageCtrl.dispose();
  }

  void _showContent(
    Map<String, dynamic> capsule, {
    bool fromReminder = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Provider.of<ThemeState>(ctx, listen: false);
        return Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.borderColor, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    XqIcon(
                      fromReminder
                          ? XqIcons.bell
                          : XqIcons.mail,
                      color: theme.accentColor,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      fromReminder ? '提醒你打开的胶囊' : '来自过去的自己',
                      style: XqTypography.headlineSmall.copyWith(
                        color: theme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  capsule['content']?.toString() ?? '',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 16,
                    height: 1.65,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '封存于 ${_shortDate(capsule['created_at'])}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('收好'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: _loading
            ? Center(child: InkWritingLoader(inkColor: theme.gold, size: 40))
            : XqRefresh(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _topBar(theme),
                    const SizedBox(height: 16),
                    _createCard(theme),
                    const SizedBox(height: 20),
                    if (_error != null)
                      _errorCard(theme)
                    else
                      _capsuleList(theme),
                    const SizedBox(height: 60),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _topBar(ThemeState theme) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: XqIcon(XqIcons.back,
            color: theme.textPrimary,
            size: 20,
          ),
        ),
        Expanded(
          child: Text(
            '时光胶囊',
            textAlign: TextAlign.center,
            style: XqTypography.headlineMedium.copyWith(
              color: theme.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }

  Widget _createCard(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: XqDecorations.surface(theme.cardColor, dark: theme.isDark, edge: theme.borderColor),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '写给未来的自己',
            style: XqTypography.headlineSmall.copyWith(
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '封好后，到日子才能打开。',
            style: TextStyle(color: theme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contentCtrl,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            style: TextStyle(color: theme.textPrimary, fontSize: 15),
            cursorColor: theme.accentColor,
            decoration: InputDecoration(
              hintText: '写给那天的自己…',
              hintStyle: TextStyle(color: theme.textSecondary.withAlpha(150)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              counterStyle: TextStyle(color: theme.textSecondary, fontSize: 11),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '$_days 天后打开',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('M月d日').format(
                  DateTime.now().add(Duration(days: _days)),
                ),
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: theme.accentColor,
              inactiveTrackColor: theme.borderColor,
              thumbColor: theme.accentColor,
            ),
            child: Slider(
              min: 1,
              max: 30,
              divisions: 29,
              value: _days.toDouble(),
              onChanged: (value) => setState(() => _days = value.round()),
            ),
          ),
          Row(
            children: [
              for (final (i, d) in const [1, 3, 7, 14, 30].indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _quickDayButton(theme, '$d天', d)),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '到那天会提醒你。',
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: XqInkLoader(),
                    )
                  : const XqIcon(XqIcons.lock, size: 18),
              label: Text(_creating ? '封存中' : '确认封存'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.accentColor,
                foregroundColor: theme.textOnAccent,
              ),
            ),
          ),
          // 通知自测入口只在调试包出现，正式包不暴露
          if (kDebugMode) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: OutlinedButton.icon(
              onPressed: _testNotification,
              icon: const XqIcon(XqIcons.hourglass, size: 16),
              label: const Text('测试通知（1 分钟后推送）'),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Future<void> _testNotification() async {
    final err = await NotificationService.scheduleQuickTest();
    if (!mounted) return;
    if (err != null) {
      XqToast.error(context, err == '系统通知未开启'
          ? '通知权限未开启，请在系统设置中允许拾晴日记发送通知'
          : err);
    } else {
      XqToast.success(context, '测试通知已设置，1 分钟后弹出，可回到桌面等待');
    }
  }

  Widget _errorCard(ThemeState theme) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(XqDecorations.radiusCard),
        border: Border.all(color: theme.borderColor),
      ),
      child: Column(
        children: [
          XqIcon(XqIcons.alert, color: theme.errorColor),
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: theme.textPrimary)),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _load, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _capsuleList(ThemeState theme) {
    if (_capsules.isEmpty) {
      return XqEmptyState(
        motif: XqMotif.boat,
        title: '还没有时光胶囊',
        subtitle: '写几句给以后的自己，到日子再打开',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '胶囊时间线',
          style: XqTypography.labelLarge.copyWith(color: theme.textSecondary),
        ),
        const SizedBox(height: 10),
        ..._capsules.map((c) => _capsuleCard(c, theme)),
      ],
    );
  }

  Widget _quickDayButton(ThemeState theme, String label, int days) {
    final active = _days == days;
    // 签条：细墨框，选中墨底反白
    return GestureDetector(
      onTap: () => setState(() => _days = days),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? theme.accentColor : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: active ? theme.accentColor : theme.controlBorder.withAlpha(150),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: active ? theme.textOnAccent : theme.textSecondary,
            fontSize: 12,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _capsuleCard(Map<String, dynamic> capsule, ThemeState theme) {
    final opened = _isOpened(capsule);
    final openDate = DateTime.tryParse(capsule['open_date']?.toString() ?? '');
    final canOpen = !opened && openDate != null && !openDate.isAfter(_today());
    final daysLeft = openDate?.difference(_today()).inDays;
    final content = capsule['content']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(capsule),
        // 胶囊 = 一封封好的信：封缄印 · 拆封日 · 还要等几天
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: XqDecorations.surface(theme.cardColor, dark: theme.isDark, edge: theme.borderColor),
          child: Row(
            children: [
              // 封缄印：没到日子是淡墨朱文「封」，到日子了是朱砂白文「启」，拆过的是淡墨「阅」
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: XqSeal(
                    char: opened ? '阅' : (canOpen ? '启' : '封'),
                    color: canOpen ? theme.sealColor : theme.textTertiary,
                    size: 34,
                    style: canOpen ? XqSealStyle.bai : XqSealStyle.zhu,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opened
                          ? '拆过了'
                          : canOpen
                          ? '到日子了，可以拆开'
                          : '${chineseNumber((openDate ?? DateTime.now()).month)}月${chineseNumber((openDate ?? DateTime.now()).day)}日拆封',
                      style: XqTypography.headlineSmall.copyWith(color: theme.textPrimary, fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opened
                          ? (content.isEmpty ? '内容已开启' : content)
                          : canOpen
                          ? '点开，看看那时写给现在的话'
                          : '还要等 ${daysLeft == null ? '--' : daysLeft.clamp(1, 999)} 天',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              XqIcon(XqIcons.chevronRight, color: theme.textTertiary, size: 20),
              if (opened)
                GestureDetector(
                  onTap: () => _deleteCapsule(capsule),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: XqIcon(XqIcons.trash, color: theme.errorColor.withAlpha(160), size: 18),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteCapsule(Map<String, dynamic> capsule) async {
    final theme = context.read<ThemeState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.cardColor,
        title: Text('删除这颗胶囊', style: TextStyle(color: theme.textPrimary)),
        content: const Text('删除后找不回来。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('取消', style: TextStyle(color: theme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text('删除', style: TextStyle(color: Theme.of(ctx).colorScheme.error))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteCapsule(capsule['id'] as int);
      NotificationService.cancelCapsuleReminder(capsule['id'] as int);
      await _load();
    } catch (_) {
      if (mounted) XqToast.info(context, '删除失败，请重试');
    }
  }

  bool _isOpened(Map<String, dynamic> capsule) {
    final value = capsule['is_opened'];
    return value == true || value == 1 || value == '1';
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  String _shortDate(dynamic value) => TimeUtils.absolute(value?.toString());

  String _notificationPreview(String text) {
    final cleaned = text.replaceAll('\n', ' ').trim();
    if (cleaned.length <= 36) return cleaned;
    return '${cleaned.substring(0, 36)}…';
  }
}

