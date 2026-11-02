const Map<int, String> moodEmojis = {
  1: '😊', 2: '😌', 3: '😢', 4: '😠',
  5: '😰', 6: '😴', 7: '🤩', 8: '🥺',
};

const Map<int, String> moodLabels = {
  1: '开心', 2: '平静', 3: '难过', 4: '生气',
  5: '焦虑', 6: '疲惫', 7: '期待', 8: '思念',
};

/// 心情釉色：低饱和、入纸不喧哗（素笺规范：避免鲜艳配色）
const Map<int, int> moodColors = {
  1: 0xFFC0964C, // 开心 · 釉金
  2: 0xFF7C918C, // 平静 · 青瓷
  3: 0xFF5F6E80, // 难过 · 墨蓝
  4: 0xFFB4574B, // 生气 · 砖红
  5: 0xFF9B8291, // 焦虑 · 藕灰
  6: 0xFF86937A, // 疲惫 · 苔灰
  7: 0xFF5E8CA0, // 期待 · 天青
  8: 0xFF8296B5, // 思念 · 雾蓝
};

final Map<int, List<Map<String, String>>> emotionTags = {
  1: [
    {'id': 'cared_for', 'icon': '🤗', 'label': '被关心'},
    {'id': 'achieved', 'icon': '🎯', 'label': '达成目标'},
    {'id': 'good_food', 'icon': '🍜', 'label': '吃到了好吃的'},
    {'id': 'gift', 'icon': '🎁', 'label': '收到礼物'},
    {'id': 'nice_weather', 'icon': '☀️', 'label': '天气好'},
    {'id': 'reunion', 'icon': '💫', 'label': '久别重逢'},
    {'id': 'happy_random', 'icon': '✨', 'label': '莫名开心'},
    {'id': 'praised', 'icon': '🌟', 'label': '被夸奖'},
  ],
  2: [
    {'id': 'daily_content', 'icon': '🍵', 'label': '日常满足'},
    {'id': 'meditated', 'icon': '🧘', 'label': '刚冥想完'},
    {'id': 'good_book', 'icon': '📖', 'label': '看了一本好书'},
    {'id': 'nature_walk', 'icon': '🌿', 'label': '自然中散步'},
    {'id': 'quiet_alone', 'icon': '🕯️', 'label': '安静独处'},
  ],
  3: [
    {'id': 'wronged', 'icon': '🥀', 'label': '委屈'},
    {'id': 'lonely', 'icon': '🌧️', 'label': '孤独'},
    {'id': 'misunderstood', 'icon': '💔', 'label': '被误解'},
    {'id': 'homesick', 'icon': '🏠', 'label': '想家了'},
    {'id': 'heartbreak', 'icon': '💧', 'label': '失恋'},
    {'id': 'stressed', 'icon': '😮‍💨', 'label': '压力大'},
    {'id': 'low_random', 'icon': '🌫️', 'label': '莫名低落'},
    {'id': 'unwell', 'icon': '🤒', 'label': '身体不舒服'},
  ],
  4: [
    {'id': 'offended', 'icon': '💢', 'label': '被冒犯'},
    {'id': 'unfair', 'icon': '⚖️', 'label': '不公平对待'},
    {'id': 'ignored', 'icon': '👤', 'label': '被忽视'},
    {'id': 'messed_up', 'icon': '💥', 'label': '事情没做好'},
    {'id': 'bad_people', 'icon': '🤬', 'label': '遇到了烂人烂事'},
  ],
  5: [
    {'id': 'work_pressure', 'icon': '💼', 'label': '工作压力'},
    {'id': 'exam_stress', 'icon': '📝', 'label': '考试前'},
    {'id': 'social_anxiety', 'icon': '🫣', 'label': '人际烦恼'},
    {'id': 'future_worry', 'icon': '🔮', 'label': '对未来的迷茫'},
    {'id': 'insomnia', 'icon': '😣', 'label': '失眠'},
    {'id': 'money_stress', 'icon': '💰', 'label': '经济压力'},
  ],
  6: [
    {'id': 'overtime', 'icon': '🕐', 'label': '加班'},
    {'id': 'study_load', 'icon': '📚', 'label': '学业负担'},
    {'id': 'social_drain', 'icon': '🔋', 'label': '社交消耗'},
    {'id': 'physical_tired', 'icon': '🛌', 'label': '身体疲劳'},
    {'id': 'mentally_drained', 'icon': '🫠', 'label': '心累'},
  ],
  7: [
    {'id': 'travel_soon', 'icon': '✈️', 'label': '即将旅行'},
    {'id': 'waiting_result', 'icon': '📬', 'label': '等一个结果'},
    {'id': 'meeting_soon', 'icon': '💝', 'label': '要见面了'},
    {'id': 'holiday_near', 'icon': '🎊', 'label': '节日快到了'},
    {'id': 'new_start', 'icon': '🚀', 'label': '新的开始'},
  ],
  8: [
    {'id': 'miss_family', 'icon': '👨‍👩‍👦', 'label': '想家人'},
    {'id': 'miss_lover', 'icon': '💌', 'label': '想恋人'},
    {'id': 'miss_friend', 'icon': '👋', 'label': '想朋友'},
    {'id': 'nostalgia', 'icon': '📷', 'label': '怀念过去'},
    {'id': 'miss_hometown', 'icon': '🌾', 'label': '思念家乡'},
  ],
};

/// Mood score for chart visualization
const Map<int, double> moodScoreMap = {
  1: 5.0, 2: 3.5, 3: 1.0, 4: 1.5,
  5: 2.0, 6: 2.5, 7: 4.0, 8: 3.0,
};
