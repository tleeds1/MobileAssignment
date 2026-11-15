import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models.dart';

class StoryRepository {
  StoryRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();
  Database get _d => _db.db;

  String newId() => _uuid.v4();

  Future<List<SocialStory>> all() async {
    final rows = await _d.query('stories', orderBy: 'updatedAt DESC');
    final result = <SocialStory>[];
    for (final r in rows) {
      result.add(await _hydrate(r));
    }
    return result;
  }

  /// Chỉ câu chuyện đã duyệt (BR-04) – dùng cho khu vực của trẻ.
  Future<List<SocialStory>> approved() async {
    final rows = await _d.query('stories',
        where: 'status = ?',
        whereArgs: [StoryStatus.approved.name],
        orderBy: 'approvedAt DESC');
    final result = <SocialStory>[];
    for (final r in rows) {
      result.add(await _hydrate(r));
    }
    return result;
  }

  Future<SocialStory?> byId(String id) async {
    final rows = await _d.query('stories', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : _hydrate(rows.first);
  }

  Future<SocialStory> _hydrate(Map<String, Object?> row) async {
    final id = row['id'] as String;
    final steps = (await _d.query('story_steps',
            where: 'storyId = ?', whereArgs: [id], orderBy: 'position'))
        .map(StoryStep.fromRow)
        .toList();
    final links = (await _d.query('story_card_links',
            where: 'storyId = ?', whereArgs: [id], orderBy: 'position'))
        .map((r) => r['cardId'] as String)
        .toList();
    return SocialStory.fromRow(row, steps: steps, linkedCardIds: links);
  }

  /// Ghi câu chuyện + các bước + liên kết thẻ trong MỘT giao dịch nguyên tử.
  Future<void> save(SocialStory s) async {
    await _d.transaction((txn) async {
      await txn.insert('stories', s.toRow(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('story_steps', where: 'storyId = ?', whereArgs: [s.id]);
      for (var i = 0; i < s.steps.length; i++) {
        await txn.insert('story_steps',
            s.steps[i].copyWith(storyId: s.id, position: i).toRow());
      }
      await _writeLinks(txn, s.id, s.linkedCardIds);
    });
  }

  /// Cập nhật liên kết thẻ hỗ trợ – KHÔNG đổi trạng thái duyệt (FR-M4-11).
  Future<void> setLinks(String storyId, List<String> cardIds) async {
    await _d.transaction((txn) => _writeLinks(txn, storyId, cardIds));
  }

  Future<void> _writeLinks(
      Transaction txn, String storyId, List<String> cardIds) async {
    await txn.delete('story_card_links',
        where: 'storyId = ?', whereArgs: [storyId]);
    for (var i = 0; i < cardIds.length; i++) {
      await txn.insert(
        'story_card_links',
        {
          'id': _uuid.v4(),
          'storyId': storyId,
          'cardId': cardIds[i],
          'position': i,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<void> delete(String id) async {
    await _d.delete('stories', where: 'id = ?', whereArgs: [id]);
  }
}
