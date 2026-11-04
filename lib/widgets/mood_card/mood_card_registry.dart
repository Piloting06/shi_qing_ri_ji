import '../../theme/xq_palette.dart';
import 'album_leaf_card_template.dart';
import 'card_kit.dart';
import 'envelope_card_template.dart';
import 'fan_card_template.dart';
import 'jian_card_template.dart';
import 'mood_card_data.dart';
import 'term_card_template.dart';
import 'week_card_template.dart';

/// 全部卡片模板（东方一系）。新增模板：写 builder → 在列表里加一条。
/// 2026-11-04 起去掉胶片 / 车票 / 火焰 / 贴纸 / 极简 / 晴收集 / 旧周历 / 旧节气（ADR-0007）。
final moodCardTemplates = <MoodCardTemplateSpec>[
  // 四张纸的「笺」（id 沿用旧笔记模板，卡片册里的旧记录能对上）
  for (final p in XqPalette.all)
    MoodCardTemplateSpec(
      id: p.id,
      name: p.name,
      label: p.paper,
      dotColors: [p.seal, p.card, p.background],
      buildCard: (data) => JianCardTemplate.build(data, p),
    ),
  MoodCardTemplateSpec(
    id: 'album',
    name: '册页',
    label: '一页小画，一页字',
    dotColors: [CardStock.silkEdge, CardStock.silk, CardStock.silk],
    buildCard: AlbumLeafCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'fan',
    name: '扇面',
    label: '洒金折扇，顺着扇骨写',
    dotColors: [CardStock.gold, CardStock.goldPaper, CardStock.goldPaper],
    buildCard: FanCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'envelope',
    name: '实寄封',
    label: '寄给以后的自己',
    dotColors: [CardStock.postRed, CardStock.envelope, CardStock.envelope],
    buildCard: EnvelopeCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'term',
    name: '节气',
    label: '这几天的物候',
    dotColors: [XqPalette.sujian.seal, XqPalette.sujian.card, XqPalette.sujian.background],
    buildCard: TermCardTemplate.build,
  ),
  MoodCardTemplateSpec(
    id: 'week',
    name: '七日',
    label: '这七天的颜色',
    dotColors: [XqPalette.sujian.gold, XqPalette.sujian.card, XqPalette.sujian.background],
    buildCard: WeekCardTemplate.build,
  ),
];

MoodCardTemplateSpec specById(String id) =>
    moodCardTemplates.firstWhere((t) => t.id == id, orElse: () => moodCardTemplates.first);
