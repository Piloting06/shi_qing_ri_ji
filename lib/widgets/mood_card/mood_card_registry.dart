import 'package:flutter/material.dart';
import 'film_card_template.dart';
import 'flame_card_template.dart';
import '../../theme/xq_palette.dart';
import 'jian_card_template.dart';
import 'mood_card_data.dart';
import 'minimal_card_template.dart';
import 'seasonal_card_template.dart';
import 'sticker_card_template.dart';
import 'sunny_card_template.dart';
import 'ticket_card_template.dart';
import 'weekly_card_template.dart';

/// 全部卡片模板。新增模板：写 builder → 在列表里加一条。
final moodCardTemplates = <MoodCardTemplateSpec>[
  // 六张纸的「笺」（id 沿用旧笔记模板 warm/dark/mint/blush，卡片册里的旧记录能对上）
  MoodCardTemplateSpec(
    id: 'sujian',
    name: XqPalette.sujian.name,
    label: XqPalette.sujian.paper,
    dotColors: [XqPalette.sujian.seal, XqPalette.sujian.card, XqPalette.sujian.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.sujian),
  ),
  MoodCardTemplateSpec(
    id: 'warm',
    name: XqPalette.warm.name,
    label: XqPalette.warm.paper,
    dotColors: [XqPalette.warm.seal, XqPalette.warm.card, XqPalette.warm.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.warm),
  ),
  MoodCardTemplateSpec(
    id: 'mint',
    name: XqPalette.mint.name,
    label: XqPalette.mint.paper,
    dotColors: [XqPalette.mint.seal, XqPalette.mint.card, XqPalette.mint.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.mint),
  ),
  MoodCardTemplateSpec(
    id: 'blush',
    name: XqPalette.blush.name,
    label: XqPalette.blush.paper,
    dotColors: [XqPalette.blush.seal, XqPalette.blush.card, XqPalette.blush.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.blush),
  ),
  MoodCardTemplateSpec(
    id: 'sujian_dark',
    name: XqPalette.cixing.name,
    label: XqPalette.cixing.paper,
    dotColors: [XqPalette.cixing.seal, XqPalette.cixing.card, XqPalette.cixing.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.cixing),
  ),
  MoodCardTemplateSpec(
    id: 'dark',
    name: XqPalette.dai.name,
    label: XqPalette.dai.paper,
    dotColors: [XqPalette.dai.seal, XqPalette.dai.card, XqPalette.dai.background],
    buildCard: (data) => JianCardTemplate.build(data, XqPalette.dai),
  ),
  MoodCardTemplateSpec(
    id: 'sunny',
    name: '晴收集',
    label: '晴天收集',
    dotColors: [Color(0xFFDE9A26), Color(0xFF6E8F5E), Color(0xFF4F7396)],
    buildCard: SunnyCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'film',
    name: '胶片',
    label: '一格胶片',
    dotColors: [Color(0xFF151412), Color(0xFF757575), Color(0xFFFF8A50)],
    buildCard: FilmCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'ticket',
    name: '车票',
    label: '一张车票',
    dotColors: [Color(0xFFC04848), Color(0xFFE8D5B0), Color(0xFF8C6B3F)],
    buildCard: TicketCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'flame',
    name: '火焰',
    label: '连续记录',
    dotColors: [Color(0xFFFF7A3D), Color(0xFFB23A1B), Color(0xFF33190A)],
    buildCard: FlameCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'weekly',
    name: '周历',
    label: '最近七天',
    dotColors: [Color(0xFF8A7350), Color(0xFFE0D5C0), Color(0xFF33291C)],
    buildCard: WeeklyCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'seasonal',
    name: '节气',
    label: '当季节气',
    dotColors: [Color(0xFF6B9A4B), Color(0xFFB27B2E), Color(0xFF6B80A0)],
    buildCard: SeasonalCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'sticker',
    name: '贴纸',
    label: '手账拼贴',
    dotColors: [Color(0xFFE8B4B8), Color(0xFFA8C6B5), Color(0xFFA5B8D0)],
    buildCard: StickerCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'minimal',
    name: '极简',
    label: '只留字',
    dotColors: [Color(0xFF2B2A27), Color(0xFF9E9B94), Color(0xFFFEFDFB)],
    buildCard: MinimalCardTemplate.build,
  ),
];

MoodCardTemplateSpec specById(String id) =>
    moodCardTemplates.firstWhere((t) => t.id == id,
        orElse: () => moodCardTemplates.first);
