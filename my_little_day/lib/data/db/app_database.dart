import 'package:sqflite/sqflite.dart';

import '../../core/date_utils.dart';
import 'seed_data.dart';

/// CSDL cục bộ (Mục 6.3–6.5).
///
/// - Mọi thay đổi ghi qua giao dịch nguyên tử (NFR-15).
/// - Lược đồ có phiên bản; migration theo từng bước, lỗi → rollback (TC-24).
/// - Lưu ý phát hành: cần mã hóa CSDL (ví dụ sqflite_sqlcipher) với khóa nằm
///   trong secure storage của nền tảng (Mục 8.4). Lớp này cô lập chỗ mở CSDL
///   để có thể thay factory mà không đổi repository.
class AppDatabase {
  AppDatabase._(this.db);

  final Database db;

  static const schemaVersion = 1;
  static const appVersion = '1.0.0';

  static Future<AppDatabase> open({
    DatabaseFactory? factory,
    String? path,
    bool seed = true,
  }) async {
    final f = factory ?? databaseFactory;
    final dbPath = path ?? '${await f.getDatabasesPath()}/my_little_day.db';
    final db = await f.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.transaction((txn) async {
            await _createV1(txn);
            await _writeAudit(txn);
            if (seed) await SeedData.insertAll(txn);
          });
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          // Mỗi bước nâng cấp chạy trong một giao dịch; nếu lỗi, giao dịch
          // rollback và ngoại lệ được ném lên để ứng dụng hiển thị phương án
          // phục hồi thay vì tiếp tục ghi vào cấu trúc không nhất quán.
          await db.transaction((txn) async {
            for (var v = oldVersion + 1; v <= newVersion; v++) {
              final step = _migrations[v];
              if (step != null) await step(txn);
            }
            await _writeAudit(txn);
          });
        },
      ),
    );
    return AppDatabase._(db);
  }

  /// Bảng migration: phiên bản đích -> hàm nâng cấp.
  static final Map<int, Future<void> Function(Transaction)> _migrations = {
    // 2: (txn) async { await txn.execute('ALTER TABLE ...'); },
  };

  static Future<void> _writeAudit(Transaction txn) async {
    // AuditMetadata – chỉ thông tin phiên bản, không chứa nội dung cá nhân.
    final now = LocalDate.isoNow();
    for (final e in {
      'appVersion': appVersion,
      'schemaVersion': '$schemaVersion',
      'migratedAt': now,
    }.entries) {
      await txn.insert(
        'app_meta',
        {'key': 'audit.${e.key}', 'value': e.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    final created = await txn.query('app_meta',
        where: 'key = ?', whereArgs: ['audit.createdAt']);
    if (created.isEmpty) {
      await txn.insert('app_meta', {'key': 'audit.createdAt', 'value': now});
    }
  }

  static Future<void> _createV1(Transaction txn) async {
    const statements = [
      '''CREATE TABLE app_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )''',
      '''CREATE TABLE routine_templates (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        weekdays TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        isSample INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE activities (
        id TEXT PRIMARY KEY,
        templateId TEXT REFERENCES routine_templates(id) ON DELETE CASCADE,
        localDate TEXT,
        title TEXT NOT NULL,
        subtitle TEXT NOT NULL DEFAULT '',
        iconKey TEXT NOT NULL,
        imageRef TEXT,
        optionalTime TEXT,
        position INTEGER NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        isSample INTEGER NOT NULL DEFAULT 0
      )''',
      'CREATE INDEX idx_activities_template ON activities(templateId)',
      'CREATE INDEX idx_activities_date ON activities(localDate)',
      '''CREATE TABLE activity_completions (
        id TEXT PRIMARY KEY,
        activityId TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
        localDate TEXT NOT NULL,
        status TEXT NOT NULL,
        completedAt TEXT NOT NULL,
        UNIQUE(activityId, localDate)
      )''',
      '''CREATE TABLE schedule_changes (
        id TEXT PRIMARY KEY,
        activityId TEXT NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
        localDate TEXT NOT NULL,
        type TEXT NOT NULL,
        replacementActivityId TEXT,
        message TEXT NOT NULL DEFAULT '',
        linkedStoryId TEXT,
        linkedCardId TEXT,
        createdAt TEXT NOT NULL,
        UNIQUE(activityId, localDate)
      )''',
      '''CREATE TABLE cards (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        speechText TEXT NOT NULL DEFAULT '',
        iconKey TEXT NOT NULL,
        imageRef TEXT,
        category TEXT NOT NULL,
        favorite INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0,
        isSample INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE card_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
        usedAt TEXT NOT NULL
      )''',
      '''CREATE TABLE emotion_options (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        iconKey TEXT NOT NULL,
        imageRef TEXT,
        kind TEXT NOT NULL,
        suggestSupport INTEGER NOT NULL DEFAULT 0,
        position INTEGER NOT NULL,
        hidden INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE emotion_entries (
        id TEXT PRIMARY KEY,
        localDateTime TEXT NOT NULL,
        selectedLabel TEXT NOT NULL,
        optionalNote TEXT NOT NULL DEFAULT ''
      )''',
      '''CREATE TABLE stories (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        source TEXT NOT NULL,
        status TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        approvedAt TEXT,
        caregiverTip TEXT NOT NULL DEFAULT '',
        scenario TEXT NOT NULL DEFAULT '',
        isSample INTEGER NOT NULL DEFAULT 0
      )''',
      '''CREATE TABLE story_steps (
        id TEXT PRIMARY KEY,
        storyId TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
        text TEXT NOT NULL,
        iconKey TEXT NOT NULL,
        imageRef TEXT,
        position INTEGER NOT NULL
      )''',
      '''CREATE TABLE story_card_links (
        id TEXT PRIMARY KEY,
        storyId TEXT NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
        cardId TEXT NOT NULL REFERENCES cards(id) ON DELETE CASCADE,
        position INTEGER NOT NULL,
        UNIQUE(storyId, cardId)
      )''',
    ];
    for (final s in statements) {
      await txn.execute(s);
    }
  }

  /// Đặt lại dữ liệu (BR-08): xóa toàn bộ nội dung, tùy chọn nạp lại mẫu.
  Future<void> resetAll({bool reseed = true}) async {
    await db.transaction((txn) async {
      for (final t in const [
        'story_card_links',
        'story_steps',
        'stories',
        'card_usage',
        'emotion_entries',
        'emotion_options',
        'schedule_changes',
        'activity_completions',
        'activities',
        'routine_templates',
        'cards',
      ]) {
        await txn.delete(t);
      }
      await txn.delete('app_meta', where: "key NOT LIKE 'audit.%'");
      if (reseed) await SeedData.insertAll(txn);
    });
  }

  /// Xóa riêng dữ liệu minh họa (BR-07).
  Future<void> deleteSampleData() async {
    await db.transaction((txn) async {
      await txn.delete('stories', where: 'isSample = 1');
      await txn.delete('activities', where: 'isSample = 1');
      await txn.delete('routine_templates', where: 'isSample = 1');
      await txn.delete('cards', where: 'isSample = 1');
    });
  }

  Future<void> close() => db.close();
}
