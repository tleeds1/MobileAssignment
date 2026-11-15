import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/date_utils.dart';
import '../db/app_database.dart';
import '../models.dart';

class EmotionRepository {
  EmotionRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();
  Database get _d => _db.db;

  String newId() => _uuid.v4();

  // ---- Lựa chọn check-in ---------------------------------------------------

  Future<List<EmotionOption>> options() async {
    final rows = await _d.query('emotion_options', orderBy: 'position');
    return rows.map(EmotionOption.fromRow).toList();
  }

  Future<void> saveOption(EmotionOption o) async {
    await _d.insert('emotion_options', o.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteOption(String id) async {
    await _d.delete('emotion_options', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Bản ghi (chỉ tạo khi trẻ chọn + xác nhận + đã bật lưu) --------------

  Future<EmotionEntry> addEntry(String label) async {
    final e = EmotionEntry(
      id: _uuid.v4(),
      localDateTime: LocalDate.isoNow(),
      selectedLabel: label,
    );
    await _d.insert('emotion_entries', e.toRow());
    return e;
  }

  Future<List<EmotionEntry>> entries({int limit = 200}) async {
    final rows = await _d.query('emotion_entries',
        orderBy: 'localDateTime DESC', limit: limit);
    return rows.map(EmotionEntry.fromRow).toList();
  }

  Future<void> deleteEntry(String id) async {
    await _d.delete('emotion_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllEntries() async {
    await _d.delete('emotion_entries');
  }

  /// Áp dụng thời hạn lưu giữ ĐÃ được người chăm sóc chọn. Không gọi khi
  /// `dataRetentionDays == null` (chưa có chính sách) – TC-10.
  Future<int> purgeOlderThan(int days) async {
    final cutoff =
        LocalDate.isoOf(DateTime.now().subtract(Duration(days: days)));
    return _d.delete('emotion_entries',
        where: 'localDateTime < ?', whereArgs: [cutoff]);
  }
}
