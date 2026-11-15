import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories/story_repository.dart';
import '../domain/story_lifecycle.dart';
import '../domain/story_validator.dart';

class StoryController extends ChangeNotifier {
  StoryController(this.repo);

  final StoryRepository repo;

  List<SocialStory> _all = const [];
  bool _loading = false;
  Object? _error;

  List<SocialStory> get all => _all;
  bool get loading => _loading;
  Object? get error => _error;

  /// Thư viện của trẻ: CHỈ câu chuyện đã duyệt (BR-04, TC-17).
  List<SocialStory> get approved =>
      _all.where((s) => s.visibleToChild).toList();

  SocialStory? byId(String id) {
    for (final s in _all) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _all = await repo.all();
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<SocialStory> createFromDraft(StoryDraft draft, String scenario) async {
    final story = StoryLifecycle.fromDraft(
      id: repo.newId(),
      draft: draft,
      scenario: scenario,
      newStepId: repo.newId,
    );
    await repo.save(story);
    await load();
    return story;
  }

  Future<SocialStory> createManual(String title) async {
    final id = repo.newId();
    final story = SocialStory(
      id: id,
      title: title,
      source: StorySource.manual,
      status: StoryStatus.draft,
      updatedAt: DateTime.now().toIso8601String(),
      steps: [
        StoryStep(
            id: repo.newId(),
            storyId: id,
            text: '',
            iconKey: 'smile',
            position: 0),
      ],
    );
    await repo.save(story);
    await load();
    return story;
  }

  /// Lưu chỉnh sửa – tự động áp dụng BR-05.
  Future<SocialStory> saveEdit(SocialStory original, SocialStory edited) async {
    final next = StoryLifecycle.applyEdit(original, edited);
    await repo.save(next);
    await load();
    return next;
  }

  Future<SocialStory> approve(SocialStory s) async {
    final next = StoryLifecycle.approve(s);
    await repo.save(next);
    await load();
    return next;
  }

  Future<SocialStory> archive(SocialStory s) async {
    final next = StoryLifecycle.archive(s);
    await repo.save(next);
    await load();
    return next;
  }

  Future<SocialStory> restore(SocialStory s) async {
    final next = StoryLifecycle.restore(s);
    await repo.save(next);
    await load();
    return next;
  }

  Future<void> setLinks(SocialStory s, List<String> cardIds) async {
    await repo.setLinks(s.id, cardIds);
    await load();
  }

  Future<void> delete(SocialStory s) async {
    await repo.delete(s.id);
    await load();
  }
}
