import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../api/api_client.dart';
import '../constants/keys.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import '../theme/xq_palette.dart';
import '../constants/app_info.dart';
import '../constants/mood.dart';
import '../widgets/main_scaffold.dart';
import '../widgets/weather_sky.dart' show chineseNumber;
import '../widgets/xq/xq_paper.dart';
import '../theme/xq_typography.dart';
import '../services/notification_service.dart';
import '../widgets/xq_toast.dart';
import '../widgets/glow_switch.dart';
import '../widgets/xq/xq_kit.dart';
import '../widgets/xq/xq_surface.dart';
import 'capsule_page.dart';
import 'friends_page.dart';
import 'legal_page.dart';
import 'login_page.dart';
import 'about_page.dart';
import 'card_album_page.dart';
import 'story_page.dart';

part 'profile_page_actions.dart';
part 'profile_page_sheets.dart';
part 'profile_page_sections.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _avatarFileKey = 'avatar_file';
  static const _legacyAvatarPathKey = 'avatar_path';

  String _avatarFileName() {
    final phone = _phone.isNotEmpty ? _phone.replaceAll(RegExp(r'[^0-9]'), '') : 'default';
    return 'avatar_$phone.jpg';
  }

  final _nameCtrl = TextEditingController();
  final _oldPwCtrl = TextEditingController();
  final _newPwCtrl = TextEditingController();
  bool _saving = false;
  bool _checkingIn = false;
  bool _checkedIn = false;
  bool _capsuleNotify = true;
  int _consecutive = 0;
  Map<int, int> _monthScores = const {}; // 本月：日 → 当天最后一笔的心情
  int _totalDays = 0;
  int _totalEntries = 0;
  int _seenMoodRevision = -1;
  String? _avatarPath;
  String _phone = '';
  String _boundEmail = '';

  // 供 part 文件中的扩展调用（扩展内直接调 setState 会触发 protected 告警）
  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    _loadProfileInfo();
    _loadCheckin();
    _loadAvatar();
  }

  /// 本月色谱 + 累计天数 / 笔数（全部来自 getAllMoods，失败静默）
  Future<void> _loadMonth() async {
    try {
      final data = await Api.getAllMoods();
      final moods = (data['moods'] as List?) ?? const [];
      final now = DateTime.now();
      final prefix = '${now.year}-${now.month.toString().padLeft(2, '0')}-';
      final month = <int, (String, int)>{};
      final dates = <String>{};
      var entries = 0;
      for (final m in moods) {
        if (m is! Map) continue;
        final date = m['date']?.toString() ?? '';
        if (date.isEmpty) continue;
        entries++;
        dates.add(date);
        final score = (m['emotion_type'] as num?)?.toInt() ?? 0;
        if (!date.startsWith(prefix) || score <= 0) continue;
        final day = int.tryParse(date.substring(prefix.length)) ?? 0;
        final at = m['created_at']?.toString() ?? '';
        final prev = month[day];
        if (prev == null || at.compareTo(prev.$1) > 0) month[day] = (at, score);
      }
      if (!mounted) return;
      setState(() {
        _monthScores = {for (final e in month.entries) e.key: e.value.$2};
        _totalDays = dates.length;
        _totalEntries = entries;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _oldPwCtrl.dispose();
    _newPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    final appState = context.watch<AppState>();

    if (appState.moodRevision != _seenMoodRevision) {
      _seenMoodRevision = appState.moodRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMonth());
    }

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: XqPaperPage(
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
            children: [
              _profileHeader(theme, appState),
              const SizedBox(height: 30),
              _monthCard(theme),
              const SizedBox(height: 28),
              _shelf(theme),
              const SizedBox(height: 30),
              _paperPicker(theme),
              const SizedBox(height: 30),
              const XqSectionTitle('设置'),
              _settingsGroup(theme, appState),
              const SizedBox(height: 14),
              _aboutGroup(theme),
              const SizedBox(height: 36),
              _colophon(theme),
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: _logout,
                  child: Text('退出登录', style: TextStyle(color: theme.textTertiary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}
