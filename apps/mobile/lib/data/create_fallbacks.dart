// Offline / empty-API catalogs for create-story chips (scheme C).
// Inspiration chips carry focus_id so the server can still resolve kernels.
// Thing chips are name-only (no DB id) → sent as keywords when selected offline.

class InspirationChip {
  const InspirationChip({
    required this.focusId,
    required this.name,
  });

  final String focusId;
  final String name;
}

/// Builtin offline fallback for theme-spark hints (see SeedHintPool + server catalog).
/// Theme/mood sparks — not full plot synopses.
const List<String> kSeedHintExamplesZh = [
  '我不想睡觉',
  '勇气与月亮',
  '小小和好',
  '今天有点委屈',
  '想变成一朵云',
  '雨声和好朋友',
  '第一次说对不起',
  '被轻轻抱抱',
];

const List<String> kSeedHintExamplesEn = [
  "I don't want to sleep",
  'courage and moonlight',
  'a tiny make-up',
  'a little sad today',
  'want to be a cloud',
  'rain and a friend',
  'saying sorry first',
  'a soft hug',
];

/// Full age-band pools aligned with server FOCUS_POOLS (short display names).
const Map<String, List<InspirationChip>> kInspirationFallback = {
  '2-3': [
    InspirationChip(focusId: 'secure_presence', name: '安心在场'),
    InspirationChip(focusId: 'body_rhythm', name: '身体节奏'),
    InspirationChip(focusId: 'name_feeling', name: '轻轻命名感受'),
  ],
  '3-5': [
    InspirationChip(focusId: 'tiny_brave', name: '小小勇敢'),
    InspirationChip(focusId: 'emotion_held', name: '情绪被接住'),
    InspirationChip(focusId: 'gentle_agency', name: '小小自主'),
    InspirationChip(focusId: 'share_space', name: '留一点空间'),
    InspirationChip(focusId: 'wind_down', name: '慢慢安静'),
  ],
  '6-8': [
    InspirationChip(focusId: 'try_persist', name: '坚持一下'),
    InspirationChip(focusId: 'friend_repair', name: '和好'),
    InspirationChip(focusId: 'fair_turn', name: '轮流公平'),
    InspirationChip(focusId: 'mentalize_light', name: '理解小心思'),
  ],
  '9-12': [
    InspirationChip(focusId: 'try_persist', name: '坚持一下'),
    InspirationChip(focusId: 'friend_repair', name: '和好'),
    InspirationChip(focusId: 'mentalize_light', name: '理解小心思'),
    InspirationChip(focusId: 'curious_cause', name: '小小因果'),
    InspirationChip(focusId: 'own_choice', name: '小小决定'),
  ],
};

/// Common soft world-thing names for offline「轻轻带上」chips (no server ids).
const List<String> kThingNameFallback = [
  '露珠',
  '影子',
  '月亮',
  '星星',
  '小毯子',
  '枕头',
  '夜灯',
  '窗台',
  '风',
  '雨声',
  '落叶',
  '小石头',
  '贝壳',
  '羽毛',
  '蒲公英',
  '蜗牛壳',
  '脚印',
  '倒影',
  '云朵',
  '萤火虫',
  '铃铛',
  '纽扣',
  '钥匙',
  '蜡烛',
  '沙漏',
  '地图',
  '气球',
  '纸船',
  '风铃',
  '暖水杯',
  '小机器人',
  '火车模型',
  '恐龙玩偶',
  '望远镜',
  '放大镜',
  '彩虹',
  '潮汐',
  '雪花',
  '蘑菇',
  '树洞',
];

List<InspirationChip> inspirationFallbackFor(String ageBand, {int limit = 12}) {
  final primary = List<InspirationChip>.from(
    kInspirationFallback[ageBand] ?? kInspirationFallback['3-5']!,
  );
  // Widen offline pool beyond the tiny per-band set.
  final seen = primary.map((e) => e.focusId).toSet();
  for (final band in kInspirationFallback.values) {
    for (final chip in band) {
      if (seen.add(chip.focusId)) primary.add(chip);
    }
  }
  final day = DateTime.now().toIso8601String().substring(0, 10);
  primary.sort(
    (a, b) => '$ageBand|$day|${a.focusId}'.hashCode
        .compareTo('$ageBand|$day|${b.focusId}'.hashCode),
  );
  return primary.take(limit.clamp(1, primary.length)).toList();
}

/// Stable daily subset so offline chips vary a bit without being tiny fixed sets.
List<String> thingFallbackSample({int limit = 12, String salt = ''}) {
  final day = DateTime.now().toIso8601String().substring(0, 10);
  final scored = <({String name, String key})>[
    for (final n in kThingNameFallback) (name: n, key: '$salt|$day|$n'),
  ];
  scored.sort((a, b) => a.key.hashCode.compareTo(b.key.hashCode));
  return scored.take(limit.clamp(1, kThingNameFallback.length)).map((e) => e.name).toList();
}
