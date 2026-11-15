import 'package:flutter/foundation.dart';

import '../core/date_utils.dart';
import '../data/models.dart';
import '../data/repositories/schedule_repository.dart';
import '../domain/schedule_logic.dart';
import 'settings_controller.dart';

class _UndoEntry {
  _UndoEntry(this.activityId, this.localDate, this.previous);
  final String activityId;
  final String localDate;
  final CompletionStatus? previous;
}

class ScheduleController extends ChangeNotifier {
  ScheduleController(this.repo, this._settings, {String Function()? today})
      : _today = today ?? LocalDate.today {
    _date = _today();
  }

  final ScheduleRepository repo;
  final SettingsController _settings;
  final String Function() _today;

  late String _date;
  DayPlan? _plan;
  bool _loading = false;
  Object? _error;
  _UndoEntry? _undo;
  Map<String, ActivityCompletion> _completions = const {};

  String get date => _date;
  DayPlan? get plan => _plan;
  bool get loading => _loading;
  Object? get error => _error;
  bool get canUndo => _undo != null;

  /// BR-09: chuyển ngày theo múi giờ thiết bị; trạng thái ngày mới không kế
  /// thừa trạng thái ngày trước (TC-04).
  Future<void> ensureToday() async {
    final t = _today();
    if (t != _date) {
      _date = t;
      _undo = null;
      await load();
    }
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final activities = await repo.activitiesForDate(_date);
      _completions = await repo.completions(_date);
      final changes = await repo.changes(_date);
      final pinned = await repo.pinnedCurrent(_date);
      _plan = ScheduleLogic.build(
        localDate: _date,
        activities: activities,
        completions: _completions,
        changes: changes,
        pinnedCurrentId: pinned,
        autoTime: _settings.value.autoTimeCurrent,
      );
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _setStatus(String activityId, CompletionStatus status) async {
    _undo = _UndoEntry(activityId, _date, _completions[activityId]?.status);
    await repo.setStatus(activityId, _date, status);
    // Bỏ chỉ định "hiện tại" nếu hoạt động được chỉ định đã kết thúc.
    if (await repo.pinnedCurrent(_date) == activityId) {
      await repo.setPinnedCurrent(_date, null);
    }
    await load();
  }

  Future<void> markDone(String activityId) =>
      _setStatus(activityId, CompletionStatus.done);

  /// "Để sau" – trung tính, không gắn nhãn tiêu cực (FR-M1-04).
  Future<void> markLater(String activityId) =>
      _setStatus(activityId, CompletionStatus.later);

  Future<void> markSkipped(String activityId) =>
      _setStatus(activityId, CompletionStatus.skipped);

  Future<void> clearStatus(String activityId) async {
    await repo.clearStatus(activityId, _date);
    await load();
  }

  /// Hoàn tác thao tác nhầm (Mục 5.5).
  Future<void> undo() async {
    final u = _undo;
    if (u == null) return;
    _undo = null;
    if (u.previous == null) {
      await repo.clearStatus(u.activityId, u.localDate);
    } else {
      await repo.setStatus(u.activityId, u.localDate, u.previous!);
    }
    await load();
  }

  void dropUndo() {
    if (_undo != null) {
      _undo = null;
      notifyListeners();
    }
  }

  Future<void> setPinnedCurrent(String? activityId) async {
    await repo.setPinnedCurrent(_date, activityId);
    await load();
  }
}
