import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/date_utils.dart';
import '../db/app_database.dart';
import '../models.dart';

class ScheduleRepository {
  ScheduleRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();
  Database get _d => _db.db;

  // ---- Mẫu lịch ------------------------------------------------------------

  Future<List<RoutineTemplate>> templates() async {
    final rows = await _d.query('routine_templates', orderBy: 'title');
    return rows.map(RoutineTemplate.fromRow).toList();
  }

  Future<RoutineTemplate> saveTemplate(RoutineTemplate t) async {
    final saved = t.copyWith(updatedAt: LocalDate.isoNow());
    await _d.insert('routine_templates', saved.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return saved;
  }

  Future<RoutineTemplate> createTemplate(String title, List<int> weekdays) =>
      saveTemplate(RoutineTemplate(
        id: _uuid.v4(),
        title: title,
        weekdays: weekdays,
        updatedAt: LocalDate.isoNow(),
      ));

  Future<void> deleteTemplate(String id) async {
    await _d.delete('routine_templates', where: 'id = ?', whereArgs: [id]);
  }

  // ---- Hoạt động -----------------------------------------------------------

  /// Danh sách hoạt động của một ngày: hoạt động từ mẫu lịch áp dụng cho thứ
  /// đó + hoạt động một lần gắn với ngày đó, theo thứ tự cấu hình.
  Future<List<Activity>> activitiesForDate(String localDate) async {
    final weekday = LocalDate.weekdayOf(localDate);
    final tpls = (await templates())
        .where((t) => t.weekdays.contains(weekday))
        .map((t) => t.id)
        .toList();
    final result = <Activity>[];
    if (tpls.isNotEmpty) {
      final placeholders = List.filled(tpls.length, '?').join(',');
      final rows = await _d.query(
        'activities',
        where: 'templateId IN ($placeholders)',
        whereArgs: tpls,
        orderBy: 'position',
      );
      result.addAll(rows.map(Activity.fromRow));
    }
    final oneOff = await _d.query('activities',
        where: 'templateId IS NULL AND localDate = ?',
        whereArgs: [localDate],
        orderBy: 'position');
    result.addAll(oneOff.map(Activity.fromRow));
    result.sort((a, b) => a.position.compareTo(b.position));
    return result;
  }

  Future<List<Activity>> activitiesForTemplate(String templateId) async {
    final rows = await _d.query('activities',
        where: 'templateId = ?', whereArgs: [templateId], orderBy: 'position');
    return rows.map(Activity.fromRow).toList();
  }

  Future<Activity?> activityById(String id) async {
    final rows =
        await _d.query('activities', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Activity.fromRow(rows.first);
  }

  String newId() => _uuid.v4();

  Future<void> saveActivity(Activity a) async {
    await _d.insert('activities', a.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deleteActivity(String id) async {
    await _d.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<Activity> duplicateActivity(Activity a) async {
    final copy = a.copyWith(id: newId(), position: a.position + 1);
    await _d.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE activities SET position = position + 1 '
        'WHERE position > ? AND (templateId IS ? AND localDate IS ?)',
        [a.position, a.templateId, a.localDate],
      );
      await txn.insert('activities', copy.toRow());
    });
    return copy;
  }

  /// Lưu thứ tự mới trong một giao dịch nguyên tử.
  Future<void> reorder(List<String> orderedIds) async {
    await _d.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('activities', {'position': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }

  // ---- Trạng thái theo ngày (BR-02) ---------------------------------------

  Future<Map<String, ActivityCompletion>> completions(String localDate) async {
    final rows = await _d.query('activity_completions',
        where: 'localDate = ?', whereArgs: [localDate]);
    return {
      for (final r in rows.map(ActivityCompletion.fromRow)) r.activityId: r,
    };
  }

  /// Ghi trạng thái; ràng buộc UNIQUE(activityId, localDate) đảm bảo thao tác
  /// thử lại không tạo bản ghi trùng (NFR-15).
  Future<void> setStatus(
      String activityId, String localDate, CompletionStatus status) async {
    await _d.insert(
      'activity_completions',
      ActivityCompletion(
        id: _uuid.v4(),
        activityId: activityId,
        localDate: localDate,
        status: status,
        completedAt: LocalDate.isoNow(),
      ).toRow(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearStatus(String activityId, String localDate) async {
    await _d.delete('activity_completions',
        where: 'activityId = ? AND localDate = ?',
        whereArgs: [activityId, localDate]);
  }

  Future<int> countDone(String fromDate, String toDate) async {
    final r = await _d.rawQuery(
      'SELECT COUNT(*) AS c FROM activity_completions '
      "WHERE status = 'done' AND localDate >= ? AND localDate <= ?",
      [fromDate, toDate],
    );
    return (r.first['c'] as int?) ?? 0;
  }

  // ---- Thay đổi lịch (UC-CH-03) -------------------------------------------

  Future<List<ScheduleChange>> changes(String localDate) async {
    final rows = await _d.query('schedule_changes',
        where: 'localDate = ?', whereArgs: [localDate]);
    return rows.map(ScheduleChange.fromRow).toList();
  }

  /// Lưu thay đổi; nếu là "thay bằng", tạo hoạt động một lần thay thế trong
  /// cùng giao dịch. Không đụng tới hoạt động khác hay trạng thái của chúng.
  Future<void> saveChange(ScheduleChange change, {Activity? replacement}) async {
    await _d.transaction((txn) async {
      if (replacement != null) {
        await txn.insert('activities', replacement.toRow(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('schedule_changes', change.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> deleteChange(ScheduleChange change) async {
    await _d.transaction((txn) async {
      await txn.delete('schedule_changes',
          where: 'id = ?', whereArgs: [change.id]);
      if (change.replacementActivityId != null) {
        await txn.delete('activities',
            where: 'id = ?', whereArgs: [change.replacementActivityId]);
      }
    });
  }

  // ---- Hoạt động hiện tại do người chăm sóc chỉ định -----------------------

  Future<String?> pinnedCurrent(String localDate) async {
    final rows = await _d.query('app_meta',
        where: 'key = ?', whereArgs: ['current.$localDate']);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  Future<void> setPinnedCurrent(String localDate, String? activityId) async {
    if (activityId == null) {
      await _d.delete('app_meta',
          where: 'key = ?', whereArgs: ['current.$localDate']);
    } else {
      await _d.insert('app_meta',
          {'key': 'current.$localDate', 'value': activityId},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  Future<List<Map<String, Object?>>> exportAll() async => [
        ...await _d.query('routine_templates'),
        ...await _d.query('activities'),
      ];
}
