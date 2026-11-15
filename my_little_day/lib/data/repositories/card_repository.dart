import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../core/date_utils.dart';
import '../db/app_database.dart';
import '../models.dart';

class CardRepository {
  CardRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();
  Database get _d => _db.db;

  String newId() => _uuid.v4();

  Future<List<CommunicationCard>> all() async {
    final rows = await _d.query('cards', orderBy: 'position');
    return rows.map(CommunicationCard.fromRow).toList();
  }

  Future<int> nextPosition() async {
    final r = await _d.rawQuery('SELECT MAX(position) AS m FROM cards');
    final m = r.first['m'] as int?;
    return (m ?? -1) + 1;
  }

  Future<void> save(CommunicationCard c) async {
    await _d.insert('cards', c.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> delete(String id) async {
    await _d.delete('cards', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> reorder(List<String> orderedIds) async {
    await _d.transaction((txn) async {
      for (var i = 0; i < orderedIds.length; i++) {
        await txn.update('cards', {'position': i},
            where: 'id = ?', whereArgs: [orderedIds[i]]);
      }
    });
  }

  // ---- Tần suất dùng thẻ (chỉ khi được bật) --------------------------------

  Future<void> logUsage(String cardId) async {
    await _d.insert(
        'card_usage', {'cardId': cardId, 'usedAt': LocalDate.isoNow()});
  }

  Future<List<CardUsage>> usageSince(String fromIso) async {
    final rows = await _d.rawQuery(
      'SELECT u.cardId AS cardId, c.label AS label, COUNT(*) AS cnt, '
      'MAX(u.usedAt) AS last FROM card_usage u JOIN cards c ON c.id = u.cardId '
      'WHERE u.usedAt >= ? GROUP BY u.cardId ORDER BY cnt DESC',
      [fromIso],
    );
    return rows
        .map((r) => CardUsage(
              cardId: r['cardId'] as String,
              label: r['label'] as String,
              count: r['cnt'] as int,
              lastUsedAt: r['last'] as String?,
            ))
        .toList();
  }

  /// Phân bố theo khung giờ (0–23) – mô tả dữ kiện, không suy diễn.
  Future<Map<int, int>> usageByHour(String fromIso) async {
    final rows = await _d.query('card_usage',
        columns: ['usedAt'], where: 'usedAt >= ?', whereArgs: [fromIso]);
    final result = <int, int>{};
    for (final r in rows) {
      final hour = int.tryParse((r['usedAt'] as String).substring(11, 13));
      if (hour != null) result[hour] = (result[hour] ?? 0) + 1;
    }
    return result;
  }

  Future<void> clearUsage() async {
    await _d.delete('card_usage');
  }
}
