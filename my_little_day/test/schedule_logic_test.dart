import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_day/data/models.dart';
import 'package:my_little_day/domain/schedule_logic.dart';

Activity act(String id, int pos, {String? time}) => Activity(
      id: id,
      templateId: 't',
      title: id,
      position: pos,
      optionalTime: time,
    );

ActivityCompletion comp(String id, CompletionStatus s) => ActivityCompletion(
      id: 'c-$id',
      activityId: id,
      localDate: '2026-11-16',
      status: s,
      completedAt: '2026-11-16T08:00:00+07:00',
    );

void main() {
  const date = '2026-11-16';
  final acts = [act('a', 0), act('b', 1), act('c', 2)];

  test('lịch rỗng → chưa xác định (empty)', () {
    final p = ScheduleLogic.build(
        localDate: date, activities: [], completions: {}, changes: []);
    expect(p.reason, UndeterminedReason.empty);
    expect(p.current, isNull);
  });

  test('theo trình tự: hoạt động đầu chưa xong là hiện tại, kế tiếp là next',
      () {
    final p = ScheduleLogic.build(
      localDate: date,
      activities: acts,
      completions: {'a': comp('a', CompletionStatus.done)},
      changes: [],
    );
    expect(p.current!.activity.id, 'b');
    expect(p.next!.activity.id, 'c');
    expect(p.doneCount, 1);
  });

  test('"Để sau" được xếp xuống cuối, không mang nhãn tiêu cực', () {
    final p = ScheduleLogic.build(
      localDate: date,
      activities: acts,
      completions: {'a': comp('a', CompletionStatus.later)},
      changes: [],
    );
    expect(p.current!.activity.id, 'b');
    expect(p.next!.activity.id, 'c');
    expect(p.items.first.state, PlanItemState.later);
  });

  test('người chăm sóc chỉ định hoạt động hiện tại', () {
    final p = ScheduleLogic.build(
      localDate: date,
      activities: acts,
      completions: {},
      changes: [],
      pinnedCurrentId: 'c',
    );
    expect(p.current!.activity.id, 'c');
  });

  test('FR-M1-11: không có giờ → KHÔNG suy ra hiện tại theo đồng hồ', () {
    final p = ScheduleLogic.build(
      localDate: date,
      activities: acts,
      completions: {},
      changes: [],
      autoTime: true,
      now: DateTime(2026, 11, 16, 23, 0),
    );
    // Không có giờ → giữ trình tự, không nhảy theo đồng hồ.
    expect(p.current!.activity.id, 'a');
  });

  test('tự xác định theo giờ khi mọi hoạt động đều có giờ', () {
    final timed = [
      act('a', 0, time: '07:00'),
      act('b', 1, time: '08:00'),
      act('c', 2, time: '09:00'),
    ];
    final p = ScheduleLogic.build(
      localDate: date,
      activities: timed,
      completions: {},
      changes: [],
      autoTime: true,
      now: DateTime(2026, 11, 16, 8, 30),
    );
    expect(p.current!.activity.id, 'b');
    expect(p.next!.activity.id, 'c');

    final early = ScheduleLogic.build(
      localDate: date,
      activities: timed,
      completions: {},
      changes: [],
      autoTime: true,
      now: DateTime(2026, 11, 16, 6, 0),
    );
    expect(early.current, isNull);
    expect(early.reason, UndeterminedReason.notStartedYet);
    expect(early.next!.activity.id, 'a');
  });

  test('UC-CH-03: hoạt động bị hủy không là hiện tại; thay thế hiển thị', () {
    const replacement = Activity(
        id: 'r', localDate: date, title: 'Chơi trong nhà', position: 1);
    final p = ScheduleLogic.build(
      localDate: date,
      activities: [...acts, replacement]
        ..sort((x, y) => x.position.compareTo(y.position)),
      completions: {},
      changes: [
        const ScheduleChange(
          id: 'x',
          activityId: 'a',
          localDate: date,
          type: ChangeType.cancelled,
          createdAt: '',
        ),
        const ScheduleChange(
          id: 'y',
          activityId: 'b',
          localDate: date,
          type: ChangeType.replaced,
          replacementActivityId: 'r',
          createdAt: '',
        ),
      ],
    );
    final a = p.items.firstWhere((i) => i.activity.id == 'a');
    expect(a.state, PlanItemState.changedOut);
    final r = p.items.firstWhere((i) => i.activity.id == 'r');
    expect(r.replaces!.id, 'b');
    expect(p.current!.activity.id, 'r');
    // Hoạt động không liên quan giữ nguyên.
    expect(p.items.firstWhere((i) => i.activity.id == 'c').change, isNull);
  });

  test('tất cả đã xong → allFinished', () {
    final p = ScheduleLogic.build(
      localDate: date,
      activities: acts,
      completions: {
        for (final a in acts) a.id: comp(a.id, CompletionStatus.done)
      },
      changes: [],
    );
    expect(p.reason, UndeterminedReason.allFinished);
    expect(p.finished.length, 3);
  });
}
