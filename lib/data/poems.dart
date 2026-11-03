import '../utils/solar_term_utils.dart';
import '../widgets/weather_sky.dart';

/// 题跋：首页笺头画右上角的一句公版古诗（竖排两列 + 落款作者）。
/// 每句按天况 × 季节 × 昼夜挑；节气命中优先，特定日期（如陆游《十一月四日风雨大作》）最优先。
/// 选句只看本地日期与天气，同一天内稳定。覆盖测试见 test/poems_test.dart。
/// 收句原则：只收通行本无异文争议的名句；新增前核对两个来源。
class Poem {
  final List<String> lines; // 两列，各 4–7 字，不带标点（竖排题跋不点断）
  final String author;
  final String title;
  final Set<SkyCondition> conditions;
  final Set<String> seasons; // spring/summer/autumn/winter；空 = 四季皆可
  final Set<String> terms; // 节气命中时优先
  final bool? night; // null = 昼夜皆可
  final (int, int)? date; // (月, 日) 命中时最优先

  const Poem(
    this.lines,
    this.author,
    this.title, {
    required this.conditions,
    this.seasons = const {},
    this.terms = const {},
    this.night,
    this.date,
  });
}

const _rain = SkyCondition.rain;
const _clear = SkyCondition.clear;
const _cloudy = SkyCondition.cloudy;
const _overcast = SkyCondition.overcast;
const _fog = SkyCondition.fog;
const _snow = SkyCondition.snow;

const poems = <Poem>[
  // ── 雨 ──
  Poem(['秋阴不散霜飞晚', '留得枯荷听雨声'], '李商隐', '宿骆氏亭寄怀崔雍崔衮',
      conditions: {_rain, _overcast}, seasons: {'autumn'}, terms: {'霜降', '寒露'}),
  Poem(['君问归期未有期', '巴山夜雨涨秋池'], '李商隐', '夜雨寄北',
      conditions: {_rain}, seasons: {'autumn'}, night: true),
  Poem(['寒雨连江夜入吴', '平明送客楚山孤'], '王昌龄', '芙蓉楼送辛渐',
      conditions: {_rain}, seasons: {'autumn', 'winter'}),
  Poem(['夜阑卧听风吹雨', '铁马冰河入梦来'], '陆游', '十一月四日风雨大作',
      conditions: {_rain, _overcast}, seasons: {'autumn', 'winter'}, night: true, date: (11, 4)),
  Poem(['好雨知时节', '当春乃发生'], '杜甫', '春夜喜雨', conditions: {_rain}, seasons: {'spring'}),
  Poem(['野径云俱黑', '江船火独明'], '杜甫', '春夜喜雨',
      conditions: {_rain}, seasons: {'spring'}, night: true),
  Poem(['小楼一夜听春雨', '深巷明朝卖杏花'], '陆游', '临安春雨初霁', conditions: {_rain}, seasons: {'spring'}),
  Poem(['清明时节雨纷纷', '路上行人欲断魂'], '杜牧', '清明',
      conditions: {_rain, _overcast}, seasons: {'spring'}, terms: {'清明'}),
  Poem(['天街小雨润如酥', '草色遥看近却无'], '韩愈', '早春呈水部张十八员外',
      conditions: {_rain}, seasons: {'spring'}, terms: {'雨水', '惊蛰'}),
  Poem(['沾衣欲湿杏花雨', '吹面不寒杨柳风'], '志南', '绝句', conditions: {_rain}, seasons: {'spring'}),
  Poem(['夜来风雨声', '花落知多少'], '孟浩然', '春晓', conditions: {_rain}, seasons: {'spring'}),
  Poem(['黄梅时节家家雨', '青草池塘处处蛙'], '赵师秀', '约客',
      conditions: {_rain}, seasons: {'summer'}, terms: {'芒种', '夏至'}),
  Poem(['东边日出西边雨', '道是无晴却有晴'], '刘禹锡', '竹枝词',
      conditions: {_rain, _cloudy}, seasons: {'summer'}, night: false),
  Poem(['空山新雨后', '天气晚来秋'], '王维', '山居秋暝',
      conditions: {_rain, _cloudy}, seasons: {'autumn'}),
  Poem(['水光潋滟晴方好', '山色空蒙雨亦奇'], '苏轼', '饮湖上初晴后雨', conditions: {_clear, _rain, _cloudy}),

  // ── 晴 ──
  Poem(['晴空一鹤排云上', '便引诗情到碧霄'], '刘禹锡', '秋词',
      conditions: {_clear}, seasons: {'autumn'}, night: false),
  Poem(['停车坐爱枫林晚', '霜叶红于二月花'], '杜牧', '山行',
      conditions: {_clear, _cloudy}, seasons: {'autumn'}, terms: {'霜降', '寒露'}, night: false),
  Poem(['月落乌啼霜满天', '江枫渔火对愁眠'], '张继', '枫桥夜泊',
      conditions: {_clear, _cloudy}, seasons: {'autumn'}, terms: {'霜降'}, night: true),
  Poem(['明月松间照', '清泉石上流'], '王维', '山居秋暝',
      conditions: {_clear}, seasons: {'summer', 'autumn'}, night: true),
  Poem(['落霞与孤鹜齐飞', '秋水共长天一色'], '王勃', '滕王阁序',
      conditions: {_clear}, seasons: {'autumn'}, night: false),
  Poem(['荷尽已无擎雨盖', '菊残犹有傲霜枝'], '苏轼', '赠刘景文',
      conditions: {_clear, _cloudy, _overcast}, seasons: {'autumn', 'winter'}, terms: {'霜降', '立冬'}),
  Poem(['两个黄鹂鸣翠柳', '一行白鹭上青天'], '杜甫', '绝句',
      conditions: {_clear}, seasons: {'spring'}, night: false),
  Poem(['竹外桃花三两枝', '春江水暖鸭先知'], '苏轼', '惠崇春江晚景',
      conditions: {_clear, _cloudy}, seasons: {'spring'}, night: false),
  Poem(['春江潮水连海平', '海上明月共潮生'], '张若虚', '春江花月夜',
      conditions: {_clear}, seasons: {'spring'}, night: true),
  Poem(['春眠不觉晓', '处处闻啼鸟'], '孟浩然', '春晓',
      conditions: {_clear, _cloudy}, seasons: {'spring'}, night: false),
  Poem(['毕竟西湖六月中', '风光不与四时同'], '杨万里', '晓出净慈寺送林子方',
      conditions: {_clear}, seasons: {'summer'}, night: false),
  Poem(['接天莲叶无穷碧', '映日荷花别样红'], '杨万里', '晓出净慈寺送林子方',
      conditions: {_clear}, seasons: {'summer'}, night: false),
  Poem(['举杯邀明月', '对影成三人'], '李白', '月下独酌', conditions: {_clear}, night: true),
  Poem(['墙角数枝梅', '凌寒独自开'], '王安石', '梅花',
      conditions: {_clear, _cloudy, _overcast}, seasons: {'winter'}),

  // ── 云 · 阴 ──
  Poem(['众鸟高飞尽', '孤云独去闲'], '李白', '独坐敬亭山', conditions: {_cloudy}, night: false),
  Poem(['行到水穷处', '坐看云起时'], '王维', '终南别业', conditions: {_cloudy, _overcast}),
  Poem(['轻阴阁小雨', '深院昼慵开'], '王维', '书事',
      conditions: {_overcast}, seasons: {'spring', 'summer'}, night: false),

  // ── 雾 ──
  Poem(['雾失楼台', '月迷津渡'], '秦观', '踏莎行', conditions: {_fog}),
  Poem(['移舟泊烟渚', '日暮客愁新'], '孟浩然', '宿建德江', conditions: {_fog, _overcast}),

  // ── 雪 ──
  Poem(['晚来天欲雪', '能饮一杯无'], '白居易', '问刘十九',
      conditions: {_snow, _overcast}, seasons: {'winter'}, terms: {'小雪', '大雪'}),
  Poem(['绿蚁新醅酒', '红泥小火炉'], '白居易', '问刘十九',
      conditions: {_snow, _overcast}, seasons: {'winter'}),
  Poem(['孤舟蓑笠翁', '独钓寒江雪'], '柳宗元', '江雪', conditions: {_snow}, seasons: {'winter'}),
  Poem(['千山鸟飞绝', '万径人踪灭'], '柳宗元', '江雪', conditions: {_snow}, seasons: {'winter'}),
  Poem(['柴门闻犬吠', '风雪夜归人'], '刘长卿', '逢雪宿芙蓉山主人',
      conditions: {_snow}, seasons: {'winter'}, night: true),
  Poem(['已讶衾枕冷', '复见窗户明'], '白居易', '夜雪', conditions: {_snow}, seasons: {'winter'}, night: true),
  Poem(['忽如一夜春风来', '千树万树梨花开'], '岑参', '白雪歌送武判官归京', conditions: {_snow}),
];

/// 挑一句：日期命中 > 节气命中 > 天况+季节+昼夜 > 放宽昼夜 > 放宽季节。同一天内稳定。
Poem poemFor(SkyCondition c, SkyTime t, DateTime day) {
  final term = currentSolarTerm(day);
  final season = seasonOfTerm(term);
  final isNight = t == SkyTime.night;
  final dayOfYear = day.difference(DateTime(day.year)).inDays;

  bool seasonOk(Poem p) => p.seasons.isEmpty || p.seasons.contains(season);
  bool nightOk(Poem p) => p.night == null || p.night == isNight;
  final byCondition = poems.where((p) => p.conditions.contains(c)).toList();

  final dated = byCondition.where((p) => p.date == (day.month, day.day) && nightOk(p));
  if (dated.isNotEmpty) return dated.first;

  for (final pool in [
    byCondition.where((p) => p.terms.contains(term) && seasonOk(p) && nightOk(p)),
    byCondition.where((p) => seasonOk(p) && nightOk(p) && p.date == null),
    byCondition.where((p) => seasonOk(p) && p.date == null),
    byCondition.where((p) => p.date == null),
  ]) {
    final list = pool.toList();
    if (list.isNotEmpty) return list[dayOfYear % list.length];
  }
  return poems.first;
}
