import 'package:flutter/material.dart';
import 'xq/xq_icons.dart';
import 'package:provider/provider.dart';
import '../api/api_client.dart';
import '../stores/theme_state.dart';
import '../theme/xq_decorations.dart';
import 'glow_wrap.dart';

class WeatherFeedbackBar extends StatefulWidget {
  final String weatherText;
  final int? currentTemp;
  final int? high;
  final int? low;
  final String cityName;

  const WeatherFeedbackBar({
    super.key,
    required this.weatherText,
    this.currentTemp,
    this.high,
    this.low,
    required this.cityName,
  });

  @override
  State<WeatherFeedbackBar> createState() => _WeatherFeedbackBarState();
}

class _WeatherFeedbackBarState extends State<WeatherFeedbackBar> {
  bool _submitted = false;

  void _submit(String type, {String? note}) {
    if (_submitted) return;
    setState(() => _submitted = true);
    Api.sendWeatherFeedback(
      type: type,
      weather: widget.weatherText,
      temp:
          '${widget.currentTemp ?? "--"}° / ${widget.low ?? "--"}° ~ ${widget.high ?? "--"}°',
      city: widget.cityName,
      note: note ?? '',
    );
  }

  void _showNoteSheet() {
    if (_submitted) return;
    final theme = context.read<ThemeState>();
    final noteCtrl = TextEditingController();
    String selectedReason = '其他';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: XqDecorations.sheetSurface(
              theme.cardColor,
              theme.borderColor,
              dark: theme.isDark,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.borderColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '哪里不准？',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '选一项就行。',
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['降雨不准', '风速不准', '天气类型不符', '其他'].map((r) {
                      final active = selectedReason == r;
                      return _feedbackChip(
                        theme,
                        label: r,
                        icon: active ? XqIcons.check : XqIcons.tune,
                        active: active,
                        onTap: () => setSheetState(() => selectedReason = r),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    style: TextStyle(color: theme.textPrimary, fontSize: 13),
                    cursorColor: theme.accentColor,
                    decoration: InputDecoration(
                      hintText: '补充说明（选填）',
                      hintStyle: TextStyle(
                        color: theme.textTertiary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: theme.borderColor),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _submit(
                          selectedReason,
                          note: noteCtrl.text.trim().isEmpty
                              ? null
                              : noteCtrl.text.trim(),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.accentColor,
                        foregroundColor: theme.textOnAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('记下来'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(noteCtrl.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeState>();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: XqDecorations.actionCard(
        theme.cardColor.withAlpha(theme.isDark ? 190 : 210),
        theme.borderColor.withAlpha(90),
        dark: theme.isDark,
        accent: theme.accentColor,
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: _submitted ? _submittedView(theme) : _feedbackView(theme),
      ),
    );
  }

  Widget _feedbackView(ThemeState theme) {
    return Column(
      key: const ValueKey('feedback'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            XqIcon(XqIcons.thermo,
              color: theme.accentColor,
              size: 17,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '今天的天气准吗？',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _feedbackChip(
              theme,
              label: '准确',
              icon: XqIcons.check,
              active: true,
              onTap: () => _submit('准确'),
            ),
            _feedbackChip(
              theme,
              label: '偏冷',
              icon: XqIcons.snow,
              onTap: () => _submit('偏冷'),
            ),
            _feedbackChip(
              theme,
              label: '偏热',
              icon: XqIcons.sunny,
              onTap: () => _submit('偏热'),
            ),
            _feedbackChip(
              theme,
              label: '降雨不准',
              icon: XqIcons.spark,
              onTap: () => _submit('降雨不准'),
            ),
            _feedbackChip(
              theme,
              label: '补充说明',
              icon: XqIcons.write,
              onTap: _showNoteSheet,
            ),
          ],
        ),
      ],
    );
  }

  Widget _submittedView(ThemeState theme) {
    return Row(
      key: const ValueKey('submitted'),
      children: [
        XqIcon(XqIcons.checkCircle,
          color: theme.successColor,
          size: 19,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '收到，谢谢',
            style: TextStyle(
              color: theme.successColor,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackChip(
    ThemeState theme, {
    required String label,
    required XqIcons icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: GlowWrap(
        accentColor: theme.accentColor,
        radius: 30,
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active
                ? theme.accentColor.withAlpha(22)
                : theme.cardElevated.withAlpha(theme.isDark ? 170 : 220),
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: active
                  ? theme.accentColor.withAlpha(90)
                  : theme.borderColor.withAlpha(100),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              XqIcon(
                icon,
                size: 15,
                color: active ? theme.accentColor : theme.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  color: active ? theme.accentColor : theme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
