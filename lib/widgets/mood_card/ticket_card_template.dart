import 'package:flutter/material.dart';
import '../../theme/xq_decorations.dart';
import '../../theme/xq_typography.dart';
import 'mood_card_data.dart';

/// 车票：复古车票版式（心情=开往的到站，日期=发车时间，天气=检票口）
const _ink = Color(0xFF4A3A28);

class TicketCardTemplate {
  TicketCardTemplate._();

  static const _stamp = Color(0xFFC04848);

  static Widget build(MoodCardData data) {
    final br = data.square ? 0.0 : 14.0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFDF),
        borderRadius: BorderRadius.circular(br),
        border: Border.all(color: _ink.withAlpha(50), width: 0.6),
        boxShadow: XqDecorations.shadowStrong(),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(br),
        child: SizedBox(
          height: data.height,
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '拾晴日记 · 心情专列',
                                style: TextStyle(
                                  color: _ink.withAlpha(150),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'SQ-${data.dateText.replaceAll(RegExp(r'[^0-9]'), '').padLeft(4, '0').substring(0, 4)}',
                                style: TextStyle(
                                  color: _stamp.withAlpha(190),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Divider(
                              height: 6,
                              thickness: 0.6,
                              color: _ink.withAlpha(40)),
                          const SizedBox(height: 6),
                          Text(
                            '开往 · ${data.moodLabel}站',
                            style: TextStyle(
                              color: _ink.withAlpha(120),
                              fontSize: 9.5,
                            ),
                          ),
                          Text(
                            data.moodEmoji,
                            style:
                                const TextStyle(fontSize: 32, height: 1.2),
                          ),
                          const SizedBox(height: 2),
                          Expanded(
                            child: Text(
                              data.bodyText.isNotEmpty
                                  ? data.bodyText
                                  : '写点什么吧',
                              style: XqTypography.handwrittenBody.copyWith(
                                color: data.bodyText.isNotEmpty
                                    ? _ink
                                    : _ink.withAlpha(60),
                                fontSize: 13,
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Row(
                            children: [
                              if (data.tags.isNotEmpty)
                                Expanded(
                                  child: Text(
                                    data.tags.take(2).join(' · '),
                                    style: TextStyle(
                                      color: _ink.withAlpha(110),
                                      fontSize: 8.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              if (data.tags.isEmpty) const Spacer(),
                              Text(
                                watermarkTextFor(data.watermark),
                                style: TextStyle(
                                  color: _ink.withAlpha(90),
                                  fontSize: 8.2,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing:
                                      data.watermark == 'sqrj' ? 1.5 : 1.15,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Transform.rotate(
                        angle: -0.16,
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _stamp.withAlpha(120),
                              width: 1.4,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '拾晴',
                            style: TextStyle(
                              color: _stamp.withAlpha(150),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const _Perforation(),
              Container(
                width: 86,
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(color: _ink.withAlpha(40), width: 0.6),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'SHI QING',
                      style: TextStyle(
                        color: _stamp.withAlpha(170),
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ticketField('发车', data.dateText),
                    _ticketField('检票口', data.moodEn),
                    if (data.weatherText != null &&
                        data.weatherText!.isNotEmpty)
                      _ticketField(
                        '天气',
                        '${data.weatherText}${data.temperature != null ? " ${data.temperature}" : ""}',
                      ),
                    const Spacer(),
                    Text(
                      '当日有效',
                      style: TextStyle(
                        color: _ink.withAlpha(90),
                        fontSize: 7.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _ticketField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: _ink.withAlpha(100),
              fontSize: 7.5,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _ink,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 撕票打孔 + 虚线
class _Perforation extends StatelessWidget {
  const _Perforation();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      child: Column(
        children: [
          const _PunchHole(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final n = (constraints.maxHeight / 12).floor();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    n,
                    (i) => Container(
                      width: 1,
                      height: 6,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: _ink.withAlpha(60),
                    ),
                  ),
                );
              },
            ),
          ),
          const _PunchHole(),
        ],
      ),
    );
  }
}

class _PunchHole extends StatelessWidget {
  const _PunchHole();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: _ink.withAlpha(40), width: 0.5),
      ),
    );
  }
}
