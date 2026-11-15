import 'package:sqflite/sqflite.dart';

import '../../core/date_utils.dart';
import '../models.dart';

/// Dữ liệu minh họa ban đầu (TC-01, BR-07): luôn gắn `isSample = 1` để có thể
/// xóa riêng; nhãn và hình chỉ là gợi ý, người chăm sóc được thay đổi.
class SeedData {
  SeedData._();

  static Future<void> insertAll(DatabaseExecutor db) async {
    final now = LocalDate.isoNow();

    // --- M1: mẫu lịch ---------------------------------------------------
    final weekday = RoutineTemplate(
      id: 'sample-tpl-school',
      title: 'Ngày đi học',
      weekdays: const [1, 2, 3, 4, 5],
      updatedAt: now,
      isSample: true,
    );
    final weekend = RoutineTemplate(
      id: 'sample-tpl-weekend',
      title: 'Cuối tuần',
      weekdays: const [6, 7],
      updatedAt: now,
      isSample: true,
    );
    await db.insert('routine_templates', weekday.toRow());
    await db.insert('routine_templates', weekend.toRow());

    const List<List<String?>> school = [
      ['Ăn sáng', 'breakfast', '06:45', ''],
      ['Đánh răng', 'toothbrush', '07:05', 'Sau khi ăn sáng'],
      ['Mặc quần áo', 'clothes', '07:15', ''],
      ['Đi học', 'school', '07:30', 'Đi xe cùng ba mẹ'],
      ['Về nhà', 'home', '16:30', ''],
      ['Chơi', 'play', '17:00', ''],
      ['Tắm', 'bath', '18:00', ''],
      ['Ăn tối', 'food', '18:30', ''],
      ['Đi ngủ', 'sleep', '20:30', ''],
    ];
    const List<List<String?>> rest = [
      ['Ăn sáng', 'breakfast', null, ''],
      ['Đánh răng', 'toothbrush', null, 'Sau khi ăn sáng'],
      ['Đi công viên', 'park', null, ''],
      ['Ăn trưa', 'food', null, ''],
      ['Nghỉ trưa', 'rest', null, ''],
      ['Vẽ tranh', 'draw', null, ''],
      ['Tắm', 'bath', null, ''],
      ['Đi ngủ', 'sleep', null, ''],
    ];
    for (var i = 0; i < school.length; i++) {
      final a = school[i];
      await db.insert(
        'activities',
        Activity(
          id: 'sample-act-school-$i',
          templateId: weekday.id,
          title: a[0]!,
          iconKey: a[1]!,
          optionalTime: a[2],
          subtitle: a[3]!,
          position: i,
          isSample: true,
        ).toRow(),
      );
    }
    for (var i = 0; i < rest.length; i++) {
      final a = rest[i];
      await db.insert(
        'activities',
        Activity(
          id: 'sample-act-weekend-$i',
          templateId: weekend.id,
          title: a[0]!,
          iconKey: a[1]!,
          optionalTime: a[2],
          subtitle: a[3]!,
          position: i,
          isSample: true,
        ).toRow(),
      );
    }

    // --- M2: thẻ giao tiếp (6 thẻ đầu giống mockup) -----------------------
    final cards = <CommunicationCard>[
      _card('water', 'Uống nước', 'Con muốn uống nước', 'water',
          CardCategory.thing, false),
      _card('rest', 'Nghỉ một chút', 'Con muốn nghỉ một chút', 'rest',
          CardCategory.help, true),
      _card('help', 'Giúp con', 'Con cần giúp đỡ', 'help', CardCategory.help,
          true),
      _card('pain', 'Con đau', 'Con bị đau', 'pain', CardCategory.urgent, true),
      _card('toilet', 'Đi vệ sinh', 'Con muốn đi vệ sinh', 'toilet',
          CardCategory.action, false),
      _card('no', 'Không thích', 'Con không thích', 'no', CardCategory.urgent,
          true),
      _card('stop', 'Dừng lại', 'Dừng lại', 'stop', CardCategory.urgent, true),
      _card('eat', 'Muốn ăn', 'Con muốn ăn', 'eat', CardCategory.action, false),
      _card('me', 'Con', 'Con', 'me', CardCategory.person, false),
      _card('want', 'Muốn', 'muốn', 'want', CardCategory.action, false),
      _card('drink', 'Uống', 'uống', 'drink', CardCategory.action, false),
      _card('juice', 'Nước cam', 'nước cam', 'juice', CardCategory.thing,
          false),
      _card('play', 'Chơi', 'chơi', 'play', CardCategory.action, false),
      _card('hug', 'Ôm', 'Ôm con nhé', 'hug', CardCategory.social, false),
      _card('yes', 'Có', 'Có', 'yes', CardCategory.social, false),
      _card('more', 'Thêm nữa', 'thêm nữa', 'more', CardCategory.describe,
          false),
      _card('quiet', 'Yên lặng', 'Con muốn yên lặng', 'quiet',
          CardCategory.describe, false),
      _card('hello', 'Xin chào', 'Xin chào', 'hello', CardCategory.social,
          false),
    ];
    for (var i = 0; i < cards.length; i++) {
      await db.insert('cards', cards[i].copyWith(position: i).toRow());
    }

    // --- M3: lựa chọn check-in (gồm cảm giác cơ thể) ----------------------
    const emotions = [
      ['happy', 'Vui', 'happy', 'feeling', 0],
      ['calm', 'Bình tĩnh', 'calm', 'feeling', 0],
      ['worried', 'Lo lắng', 'worried', 'feeling', 1],
      ['sad', 'Buồn', 'sad', 'feeling', 1],
      ['upset', 'Khó chịu', 'upset', 'feeling', 1],
      ['tired', 'Mệt', 'tired', 'feeling', 1],
      ['headache', 'Đau đầu', 'headache', 'body', 1],
      ['hot', 'Nóng người', 'hot_body', 'body', 1],
      ['shout', 'Muốn hét', 'shout', 'body', 1],
      ['tummy', 'Bụng cồn cào', 'tummy', 'body', 1],
    ];
    for (var i = 0; i < emotions.length; i++) {
      final e = emotions[i];
      await db.insert('emotion_options', {
        'id': 'emo-${e[0]}',
        'label': e[1],
        'iconKey': e[2],
        'imageRef': null,
        'kind': e[3],
        'suggestSupport': e[4],
        'position': i,
        'hidden': 0,
      });
    }

    // --- M4: câu chuyện minh họa -----------------------------------------
    await _story(
      db,
      id: 'sample-story-doctor',
      title: 'Đi khám',
      status: StoryStatus.approved,
      approvedAt: now,
      now: now,
      steps: const [
        ['Con đi xe đến phòng khám.', 'car'],
        ['Con ngồi chờ cùng người lớn.', 'clock'],
        ['Bác sĩ có thể nhìn tai của con.', 'doctor'],
        ['Con có thể chọn thẻ nghỉ.', 'rest'],
        ['Xong rồi, con về nhà.', 'home'],
      ],
      linkedCards: const ['sample-card-rest', 'sample-card-help'],
    );
    await _story(
      db,
      id: 'sample-story-library',
      title: 'Con sẽ đến thư viện',
      status: StoryStatus.draft,
      now: now,
      steps: const [
        ['Con đến thư viện cùng người lớn.', 'home'],
        ['Ở đó có sách và nhiều người.', 'book'],
        ['Nếu cần, con có thể chọn thẻ nghỉ.', 'rest'],
        ['Sau đó, con về nhà cùng người lớn.', 'done'],
      ],
      linkedCards: const [],
    );
  }

  static CommunicationCard _card(String key, String label, String speech,
          String icon, CardCategory cat, bool favorite) =>
      CommunicationCard(
        id: 'sample-card-$key',
        label: label,
        speechText: speech,
        iconKey: icon,
        category: cat,
        favorite: favorite,
        position: 0,
        isSample: true,
      );

  static Future<void> _story(
    DatabaseExecutor db, {
    required String id,
    required String title,
    required StoryStatus status,
    String? approvedAt,
    required String now,
    required List<List<String>> steps,
    required List<String> linkedCards,
  }) async {
    await db.insert(
      'stories',
      SocialStory(
        id: id,
        title: title,
        source: StorySource.template,
        status: status,
        updatedAt: now,
        approvedAt: approvedAt,
        caregiverTip: 'Đây là dữ liệu minh họa – hãy chỉnh theo thực tế.',
        isSample: true,
      ).toRow(),
    );
    for (var i = 0; i < steps.length; i++) {
      await db.insert(
        'story_steps',
        StoryStep(
          id: '$id-s$i',
          storyId: id,
          text: steps[i][0],
          iconKey: steps[i][1],
          position: i,
        ).toRow(),
      );
    }
    for (var i = 0; i < linkedCards.length; i++) {
      await db.insert('story_card_links', {
        'id': '$id-l$i',
        'storyId': id,
        'cardId': linkedCards[i],
        'position': i,
      });
    }
  }
}
