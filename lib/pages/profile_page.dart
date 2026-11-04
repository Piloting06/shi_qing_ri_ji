import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../widgets/xq/xq_icons.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../api/api_client.dart';
import '../constants/keys.dart';
import '../stores/app_state.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
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

    return Scaffold(
      backgroundColor: theme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: [
            _profileHeader(theme, appState),
            const SizedBox(height: 32),

            _sectionTitle('记录', theme),
            _card(theme, child: _recordsGroup(theme)),
            const SizedBox(height: 28),

            _sectionTitle('个人资料', theme),
            _profileSettingsGroup(theme, appState),
            const SizedBox(height: 28),

            _sectionTitle('外观与偏好', theme),
            _appearanceGroup(theme),
            const SizedBox(height: 28),

            _sectionTitle('账号与安全', theme),
            _securityGroup(theme),
            const SizedBox(height: 28),

            _sectionTitle('关于与帮助', theme),
            _aboutGroup(theme),
            const SizedBox(height: 28),

            // 退出登录（低调 footer 样式）
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _logout,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '退出登录',
                    style: TextStyle(
                      color: theme.textTertiary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
