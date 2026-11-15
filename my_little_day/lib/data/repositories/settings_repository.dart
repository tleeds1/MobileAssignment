import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models.dart';

class SettingsRepository {
  SettingsRepository(this._db);

  final AppDatabase _db;
  static const _key = 'settings';

  Future<AppSettings> load() async {
    final rows = await _db.db
        .query('app_meta', where: 'key = ?', whereArgs: [_key], limit: 1);
    if (rows.isEmpty) return const AppSettings();
    try {
      return AppSettings.decode(rows.first['value'] as String);
    } catch (_) {
      // Dữ liệu hỏng → dùng cấu hình tối giản thay vì làm sập ứng dụng.
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings s) async {
    await _db.db.insert(
      'app_meta',
      {'key': _key, 'value': s.encode()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMeta(String key) async {
    final rows = await _db.db
        .query('app_meta', where: 'key = ?', whereArgs: [key], limit: 1);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setMeta(String key, String? value) async {
    if (value == null) {
      await _db.db.delete('app_meta', where: 'key = ?', whereArgs: [key]);
    } else {
      await _db.db.insert('app_meta', {'key': key, 'value': value},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<Map<String, String>> auditMetadata() async {
    final rows = await _db.db
        .query('app_meta', where: "key LIKE 'audit.%'");
    return {
      for (final r in rows)
        (r['key'] as String).substring(6): r['value'] as String,
    };
  }
}
