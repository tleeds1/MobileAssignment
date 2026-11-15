import '../core/date_utils.dart';
import '../data/models.dart';

enum PlanItemState { planned, current, next, done, later, skipped, changedOut }

class PlanItem {
  const PlanItem({
    required this.activity,
    required this.state,
    this.change,
    this.replaces,
  });

  final Activity activity;
  final PlanItemState state;

  /// Thay đổi trong ngày gắn với hoạt động này (nếu có).
  final ScheduleChange? change;

  /// Nếu đây là hoạt động thay thế: hoạt động gốc bị thay.
  final Activity? replaces;

  bool get isChanged => change != null || replaces != null;
  bool get isFinished =>
      state == PlanItemState.done || state == PlanItemState.skipped;
}

enum UndeterminedReason { none, empty, allFinished, notStartedYet }

class DayPlan {
  const DayPlan({
    required this.localDate,
    required this.items,
    this.current,
    this.next,
    this.reason = UndeterminedReason.none,
  });

  final String localDate;
  final List<PlanItem> items;
  final PlanItem? current;
  final PlanItem? next;
  final UndeterminedReason reason;

  int get doneCount =>
      items.where((i) => i.state == PlanItemState.done).length;
  List<PlanItem> get finished => items.where((i) => i.isFinished).toList();
  List<PlanItem> get changed => items.where((i) => i.isChanged).toList();
}

/// Quy tắc xác định hoạt động hiện tại/kế tiếp (FR-M1-11, Mục 3.4.1):
///
/// 1. Hoạt động người chăm sóc chỉ định (nếu còn hợp lệ).
/// 2. Nếu bật "tự xác định theo giờ" VÀ mọi hoạt động còn lại đều có giờ:
///    hoạt động gần nhất đã đến giờ. Chưa tới giờ hoạt động đầu → chưa xác định.
/// 3. Ngược lại: theo trình tự – hoạt động đầu tiên chưa hoàn tất.
///    (Đây là kết quả của thao tác người dùng, không phải suy đoán theo giờ.)
///
/// Hoạt động bị hủy/hoãn/thay thế/chưa xác định không được chọn làm hiện tại.
class ScheduleLogic {
  ScheduleLogic._();

  static DayPlan build({
    required String localDate,
    required List<Activity> activities,
    required Map<String, ActivityCompletion> completions,
    required List<ScheduleChange> changes,
    String? pinnedCurrentId,
    bool autoTime = false,
    DateTime? now,
  }) {
    if (activities.isEmpty) {
      return DayPlan(
          localDate: localDate,
          items: const [],
          reason: UndeterminedReason.empty);
    }

    final changeByActivity = {for (final c in changes) c.activityId: c};
    final byId = {for (final a in activities) a.id: a};
    final replacedBy = <String, Activity>{}; // replacementId -> original
    for (final c in changes) {
      if (c.type == ChangeType.replaced && c.replacementActivityId != null) {
        final orig = byId[c.activityId];
        if (orig != null) replacedBy[c.replacementActivityId!] = orig;
      }
    }

    bool excluded(Activity a) {
      final c = changeByActivity[a.id];
      if (c == null) return false;
      return c.type == ChangeType.cancelled ||
          c.type == ChangeType.postponed ||
          c.type == ChangeType.replaced ||
          c.type == ChangeType.undecided;
    }

    // Các hoạt động còn có thể làm "hiện tại", "để sau" xếp cuối.
    final open = <Activity>[];
    final openLater = <Activity>[];
    for (final a in activities) {
      if (excluded(a)) continue;
      final st = completions[a.id]?.status;
      if (st == CompletionStatus.done || st == CompletionStatus.skipped) {
        continue;
      }
      (st == CompletionStatus.later ? openLater : open).add(a);
    }
    final candidates = [...open, ...openLater];

    Activity? current;
    var reason = UndeterminedReason.none;

    if (candidates.isEmpty) {
      reason = UndeterminedReason.allFinished;
    } else {
      final pinned = pinnedCurrentId == null
          ? null
          : candidates.where((a) => a.id == pinnedCurrentId).toList();
      if (pinned != null && pinned.isNotEmpty) {
        current = pinned.first;
      } else if (autoTime &&
          open.isNotEmpty &&
          open.every((a) => LocalDate.minutesOf(a.optionalTime) != null)) {
        final t = now ?? DateTime.now();
        final nowMin = t.hour * 60 + t.minute;
        final timed = [...open]..sort((a, b) => LocalDate.minutesOf(
                a.optionalTime)!
            .compareTo(LocalDate.minutesOf(b.optionalTime)!));
        final started = timed
            .where((a) => LocalDate.minutesOf(a.optionalTime)! <= nowMin)
            .toList();
        if (started.isEmpty) {
          reason = UndeterminedReason.notStartedYet;
        } else {
          current = started.last;
        }
      } else {
        current = candidates.first;
      }
    }

    Activity? next;
    if (current != null) {
      final idx = candidates.indexOf(current);
      if (idx >= 0 && idx + 1 < candidates.length) next = candidates[idx + 1];
    } else if (reason == UndeterminedReason.notStartedYet) {
      next = candidates.first;
    }

    PlanItemState stateOf(Activity a) {
      if (excluded(a)) return PlanItemState.changedOut;
      if (identical(a, current)) return PlanItemState.current;
      if (identical(a, next)) return PlanItemState.next;
      final st = completions[a.id]?.status;
      if (st == CompletionStatus.done) return PlanItemState.done;
      if (st == CompletionStatus.skipped) return PlanItemState.skipped;
      if (st == CompletionStatus.later) return PlanItemState.later;
      return PlanItemState.planned;
    }

    final items = activities
        .map((a) => PlanItem(
              activity: a,
              state: stateOf(a),
              change: changeByActivity[a.id],
              replaces: replacedBy[a.id],
            ))
        .toList();

    PlanItem? find(Activity? a) =>
        a == null ? null : items.firstWhere((i) => identical(i.activity, a));

    return DayPlan(
      localDate: localDate,
      items: items,
      current: find(current),
      next: find(next),
      reason: reason,
    );
  }
}
