import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_day/core/date_utils.dart';
import 'package:my_little_day/data/db/app_database.dart';
import 'package:my_little_day/data/models.dart';
import 'package:my_little_day/data/repositories/card_repository.dart';
import 'package:my_little_day/data/repositories/emotion_repository.dart';
import 'package:my_little_day/data/repositories/schedule_repository.dart';
import 'package:my_little_day/data/repositories/story_repository.dart';
import 'package:my_little_day/domain/story_lifecycle.dart';
import 'package:my_little_day/services/tts_service.dart';
import 'package:my_little_day/state/card_controller.dart';
import 'package:my_little_day/state/emotion_controller.dart';
import 'package:my_little_day/state/settings_controller.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Kiểm thử tích hợp tầng dữ liệu với SQLite trong bộ nhớ.
void main() {
  sqfliteFfiInit();
  late AppDatabase db;
  late ScheduleRepository schedule;
  late StoryRepository stories;
  late EmotionRepository emotions;
  late CardRepository cards;

  // Thứ Hai (template "Ngày đi học" áp dụng T2–T6).
  const monday = '2026-11-16';
  const tuesday = '2026-11-17';

  setUp(() async {
    db = await AppDatabase.open(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    schedule = ScheduleRepository(db);
    stories = StoryRepository(db);
    emotions = EmotionRepository(db);
    cards = CardRepository(db);
  });

  tearDown(() => db.close());

  test('TC-01: lần chạy đầu có dữ liệu mẫu được đánh dấu minh họa', () async {
    final acts = await schedule.activitiesForDate(monday);
    expect(acts, isNotEmpty);
    expect(acts.every((a) => a.isSample), isTrue);
    expect((await cards.all()).every((c) => c.isSample), isTrue);
  });

  test('TC-03/04: hoàn tất gắn đúng hoạt động + đúng ngày; ngày mới sạch',
      () async {
    final a = (await schedule.activitiesForDate(monday)).first;
    await schedule.setStatus(a.id, monday, CompletionStatus.done);
    expect((await schedule.completions(monday))[a.id]!.status,
        CompletionStatus.done);
    expect(await schedule.completions(tuesday), isEmpty);
  });

  test('NFR-15: ghi lặp không tạo bản ghi trùng', () async {
    final a = (await schedule.activitiesForDate(monday)).first;
    await schedule.setStatus(a.id, monday, CompletionStatus.done);
    await schedule.setStatus(a.id, monday, CompletionStatus.done);
    final rows = await db.db.query('activity_completions');
    expect(rows.length, 1);
  });

  test('TC-26: thay một hoạt động không ảnh hưởng hoạt động khác', () async {
    final acts = await schedule.activitiesForDate(monday);
    await schedule.setStatus(acts[0].id, monday, CompletionStatus.done);
    final replacement = Activity(
        id: schedule.newId(),
        localDate: monday,
        title: 'Chơi trong nhà',
        position: acts[1].position);
    await schedule.saveChange(
      ScheduleChange(
        id: schedule.newId(),
        activityId: acts[1].id,
        localDate: monday,
        type: ChangeType.replaced,
        replacementActivityId: replacement.id,
        createdAt: LocalDate.isoNow(),
      ),
      replacement: replacement,
    );
    final after = await schedule.activitiesForDate(monday);
    expect(after.length, acts.length + 1);
    expect((await schedule.completions(monday))[acts[0].id]!.status,
        CompletionStatus.done);
    // Mẫu lịch ngày khác không bị đổi.
    expect((await schedule.changes(tuesday)), isEmpty);
    expect((await schedule.activitiesForDate(tuesday)).length, acts.length);
  });

  test('TC-17: thư viện của trẻ chỉ có câu chuyện đã duyệt', () async {
    final approved = await stories.approved();
    expect(approved.every((s) => s.status == StoryStatus.approved), isTrue);
    final all = await stories.all();
    expect(all.any((s) => s.status == StoryStatus.draft), isTrue);
  });

  test('BR-05 + lưu nguyên tử: sửa câu chuyện đã duyệt → bản nháp', () async {
    final s = (await stories.approved()).first;
    final next = StoryLifecycle.applyEdit(s, s.copyWith(title: 'Mới'));
    await stories.save(next);
    expect((await stories.approved()).any((x) => x.id == s.id), isFalse);
    expect((await stories.byId(s.id))!.steps.length, s.steps.length);
  });

  test('FR-M4-11: đổi liên kết thẻ không đổi trạng thái duyệt', () async {
    final s = (await stories.approved()).first;
    await stories.setLinks(s.id, ['sample-card-water']);
    final again = await stories.byId(s.id);
    expect(again!.status, StoryStatus.approved);
    expect(again.linkedCardIds, ['sample-card-water']);
  });

  test('TC-08: không bật lưu lịch sử → check-in không tạo bản ghi', () async {
    final settings = SettingsController.preview(const AppSettings());
    final ctrl = EmotionController(emotions, settings);
    await ctrl.load();
    final saved = await ctrl.confirm(ctrl.options.first);
    expect(saved, isFalse);
    expect(await emotions.entries(), isEmpty);

    await settings.update(settings.value.copyWith(emotionHistoryEnabled: true));
    expect(await ctrl.confirm(ctrl.options.first), isTrue);
    expect((await emotions.entries()).length, 1);
  });

  test('TC-10: chưa có thời hạn lưu giữ → không tự xóa', () async {
    final settings = SettingsController.preview(
        const AppSettings(emotionHistoryEnabled: true));
    final ctrl = EmotionController(emotions, settings);
    await db.db.insert('emotion_entries', {
      'id': 'old',
      'localDateTime': '2020-01-01T08:00:00+07:00',
      'selectedLabel': 'Vui',
      'optionalNote': '',
    });
    await ctrl.applyRetention();
    expect((await emotions.entries()).length, 1);

    await settings.update(settings.value.copyWith(dataRetentionDays: 30));
    await ctrl.applyRetention();
    expect(await emotions.entries(), isEmpty);
  });

  test('chạm thẻ không ghi lượt dùng khi chưa bật; bật thì ghi', () async {
    final settings = SettingsController.preview(const AppSettings());
    final speech = SilentSpeechService();
    final ctrl = CardController(cards, settings, speech);
    await ctrl.load();
    final c = ctrl.visible.first;
    await ctrl.use(c, addToSentence: true);
    expect(await db.db.query('card_usage'), isEmpty);
    expect(speech.spoken, [c.spoken]);
    expect(ctrl.sentence.length, 1);

    await settings.update(settings.value.copyWith(cardUsageLogEnabled: true));
    await ctrl.use(c);
    expect((await cards.usageSince('2000-01-01')).first.count, 1);
  });

  test('Chế độ yên tĩnh: không phát âm thanh', () async {
    final settings =
        SettingsController.preview(const AppSettings(quietMode: true));
    final speech = SilentSpeechService();
    final ctrl = CardController(cards, settings, speech);
    await ctrl.load();
    await ctrl.use(ctrl.visible.first);
    expect(speech.spoken, isEmpty);
  });

  test('Thanh ghép câu: CON + MUỐN + UỐNG + NƯỚC CAM', () async {
    final settings = SettingsController.preview(const AppSettings());
    final ctrl = CardController(cards, settings, SilentSpeechService());
    await ctrl.load();
    for (final id in ['me', 'want', 'drink', 'juice']) {
      await ctrl.use(ctrl.byId('sample-card-$id')!, addToSentence: true);
    }
    expect(ctrl.sentenceText, 'Con muốn uống nước cam');
    ctrl.removeLast();
    expect(ctrl.sentenceText, 'Con muốn uống');
  });

  test('BR-07: xóa dữ liệu minh họa giữ nội dung người dùng tạo', () async {
    final mine = CommunicationCard(
        id: 'mine', label: 'Bánh', position: await cards.nextPosition());
    await cards.save(mine);
    await db.deleteSampleData();
    final left = await cards.all();
    expect(left.map((c) => c.id), ['mine']);
    expect(await stories.all(), isEmpty);
  });

  test('BR-08: đặt lại xóa dữ liệu và nạp lại mẫu; giữ audit metadata',
      () async {
    await emotions.addEntry('Vui');
    await db.resetAll();
    expect(await emotions.entries(), isEmpty);
    expect(await cards.all(), isNotEmpty);
    final audit = await db.db.query('app_meta', where: "key LIKE 'audit.%'");
    expect(audit, isNotEmpty);
  });
}
