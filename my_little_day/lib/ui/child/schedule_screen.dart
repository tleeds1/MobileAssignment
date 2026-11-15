import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/strings.dart';
import '../../core/tap_guard.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../domain/schedule_logic.dart';
import '../../services/tts_service.dart';
import '../../state/schedule_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/hold_to_confirm_button.dart';
import '../widgets/pictogram.dart';

/// M1 – Lịch trình trong ngày (UC-CH-02, UC-CH-03, Hình 5).
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key, required this.onOpenCaregiver});

  final VoidCallback onOpenCaregiver;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<ScheduleController>();
    final settings = context.watch<SettingsController>().value;
    final plan = ctrl.plan;

    Widget body;
    if (ctrl.error != null && plan == null) {
      body = EmptyState(
        icon: Icons.refresh_rounded,
        title: 'Chưa mở được lịch.',
        hint: 'Có thể thử lại.',
        action: OutlinedButton(
            onPressed: ctrl.load, child: const Text('Thử lại')),
      );
    } else if (plan == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (plan.reason == UndeterminedReason.empty) {
      body = const EmptyState(
        icon: Icons.calendar_today_outlined,
        title: S.noScheduleToday,
        hint: S.noScheduleHint,
      );
    } else {
      switch (settings.scheduleViewMode) {
        case ScheduleViewMode.single:
        case ScheduleViewMode.nowNext:
          body = _NowNextView(
            plan: plan,
            showNext: settings.scheduleViewMode == ScheduleViewMode.nowNext,
          );
          break;
        case ScheduleViewMode.fullDay:
          body = _FullDayView(plan: plan);
          break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 72),
          child: ChildHeader(
            title: 'Lịch của ${settings.preferredName}',
            subtitle: LocalDate.friendly(ctrl.date),
            onSecret: onOpenCaregiver,
          ),
        ),
        if (plan != null && plan.changed.isNotEmpty)
          _ChangeBanner(plan: plan),
        Expanded(child: body),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

Future<void> _markDone(BuildContext context, PlanItem item) async {
  final ctrl = context.read<ScheduleController>();
  final messenger = ScaffoldMessenger.of(context);
  await ctrl.markDone(item.activity.id);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Đã xong: ${item.activity.title}'),
      action: SnackBarAction(label: S.undo, onPressed: ctrl.undo),
    ));
}

void _speak(BuildContext context, String text) {
  final s = context.read<SettingsController>().value;
  if (s.canSpeak) context.read<SpeechService>().speak(text, rate: s.ttsRate);
}

/// Chế độ "Một việc" / "Bây giờ – Tiếp theo".
class _NowNextView extends StatelessWidget {
  const _NowNextView({required this.plan, required this.showNext});

  final DayPlan plan;
  final bool showNext;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final motion = settings.animationsOn
        ? const Duration(milliseconds: 450)
        : Duration.zero;
    final current = plan.current;
    final next = plan.next;

    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
      children: [
        if (current != null) ...[
          const Align(
              alignment: Alignment.centerLeft, child: Pill(S.now)),
          const SizedBox(height: Gap.s),
          // Khi xong: thẻ hiện tại trượt xuống "hộp Đã xong", thẻ kế tiếp
          // trượt lên vị trí BÂY GIỜ (góp ý: tư duy cụ thể – thấy rõ kết thúc).
          AnimatedSwitcher(
            duration: motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => SlideTransition(
              position: Tween<Offset>(
                      begin: const Offset(0, 0.9), end: Offset.zero)
                  .animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _NowCard(key: ValueKey(current.activity.id), item: current),
          ),
        ] else
          _UndeterminedNotice(plan: plan),
        if (showNext && next != null) ...[
          const SizedBox(height: Gap.l),
          const Align(
              alignment: Alignment.centerLeft,
              child: Pill(S.next, color: AppColors.lightBlue)),
          const SizedBox(height: Gap.s),
          AnimatedSwitcher(
            duration: motion,
            child: _ActivityRow(key: ValueKey(next.activity.id), item: next),
          ),
        ],
        const SizedBox(height: Gap.l),
        _DoneTray(plan: plan),
      ],
    );
  }
}

class _UndeterminedNotice extends StatelessWidget {
  const _UndeterminedNotice({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final allDone = plan.reason == UndeterminedReason.allFinished;
    return Container(
      padding: const EdgeInsets.all(Gap.l),
      decoration: BoxDecoration(
        color: allDone ? AppColors.accentBg : AppColors.cream,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(allDone ? Icons.check_circle_rounded : Icons.schedule_rounded,
              size: 64, color: AppColors.primary),
          const SizedBox(height: Gap.s),
          Text(
            allDone ? S.allFinished : S.notDetermined,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _NowCard extends StatelessWidget {
  const _NowCard({super.key, required this.item});
  final PlanItem item;

  @override
  Widget build(BuildContext context) {
    final a = item.activity;
    final settings = context.watch<SettingsController>().value;
    return Semantics(
      container: true,
      label: 'Đang diễn ra: ${a.title}',
      child: Container(
        padding: const EdgeInsets.all(Gap.m),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary, width: 2.5),
          boxShadow: const [
            BoxShadow(color: AppColors.shadow, offset: Offset(0, 6), blurRadius: 12),
          ],
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => _openDetail(context, item),
              child: Container(
                height: 170,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Pictogram(
                    iconKey: a.iconKey,
                    imageRef: a.imageRef,
                    size: 130,
                  ),
                ),
              ),
            ),
            const SizedBox(height: Gap.m),
            if (item.isChanged) ...[
              const Pill(S.changedBadge,
                  color: AppColors.lightBlue, icon: Icons.swap_horiz_rounded),
              const SizedBox(height: Gap.s),
            ],
            Text(a.title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            if (a.optionalTime != null || a.subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  [
                    if (a.optionalTime != null) a.optionalTime!,
                    if (a.subtitle.isNotEmpty) a.subtitle,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 16, color: AppColors.muted),
                ),
              ),
            const SizedBox(height: Gap.m),
            HoldToConfirmButton(
              label: S.done,
              holdLabel: S.holdToFinish,
              requireHold: settings.doneNeedsHold,
              haptics: settings.vibrationEnabled && !settings.quietMode,
              semanticsLabel: 'Đánh dấu ${a.title} là xong',
              onConfirmed: () => _markDone(context, item),
            ),
            const SizedBox(height: Gap.s),
            TextButton.icon(
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: () =>
                  context.read<ScheduleController>().markLater(a.id),
              icon: const Icon(Icons.schedule_rounded),
              label: const Text(S.later, style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({super.key, required this.item, this.dense = false});
  final PlanItem item;
  final bool dense;

  String get _stateLabel {
    switch (item.state) {
      case PlanItemState.current:
        return 'Đang diễn ra';
      case PlanItemState.next:
        return 'Tiếp theo';
      case PlanItemState.done:
        return 'Hoàn tất';
      case PlanItemState.later:
        return 'Để sau';
      case PlanItemState.skipped:
        return 'Bỏ qua';
      case PlanItemState.changedOut:
        return item.change?.type.label ?? 'Có thay đổi';
      case PlanItemState.planned:
        return 'Sắp tới';
    }
  }

  IconData get _stateIcon {
    switch (item.state) {
      case PlanItemState.current:
        return Icons.play_circle_fill_rounded;
      case PlanItemState.done:
        return Icons.check_circle_rounded;
      case PlanItemState.later:
        return Icons.schedule_rounded;
      case PlanItemState.skipped:
        return Icons.skip_next_rounded;
      case PlanItemState.changedOut:
        return Icons.swap_horiz_rounded;
      case PlanItemState.next:
        return Icons.arrow_circle_right_rounded;
      case PlanItemState.planned:
        return Icons.radio_button_unchecked_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = item.activity;
    final finished = item.isFinished || item.state == PlanItemState.changedOut;
    final current = item.state == PlanItemState.current;
    return Semantics(
      button: true,
      label: '${a.title}, $_stateLabel',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _openDetail(context, item),
        child: Container(
          padding: EdgeInsets.all(dense ? Gap.s + 4 : Gap.m),
          decoration: BoxDecoration(
            color: current ? AppColors.accentBg : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: current ? AppColors.primary : AppColors.border,
              width: current ? 2.5 : 1.5,
            ),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: finished ? 0.5 : 1,
                child: Pictogram(
                    iconKey: a.iconKey,
                    imageRef: a.imageRef,
                    size: dense ? 52 : 72),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title,
                        style: TextStyle(
                          fontSize: dense ? 19 : 22,
                          fontWeight: FontWeight.w800,
                          color: finished ? AppColors.muted : AppColors.text,
                        )),
                    if (item.replaces != null)
                      Text('Thay cho: ${item.replaces!.title}',
                          style: const TextStyle(color: AppColors.muted)),
                    if (item.change != null && item.change!.message.isNotEmpty)
                      Text(item.change!.message,
                          style: const TextStyle(color: AppColors.muted)),
                    if (a.subtitle.isNotEmpty || a.optionalTime != null)
                      Text(
                        [
                          if (a.optionalTime != null) a.optionalTime!,
                          if (a.subtitle.isNotEmpty) a.subtitle,
                        ].join(' · '),
                        style: const TextStyle(color: AppColors.muted),
                      ),
                  ],
                ),
              ),
              // Trạng thái luôn có biểu tượng + chữ, không chỉ dựa vào màu.
              Column(
                children: [
                  Icon(_stateIcon, color: AppColors.primary),
                  Text(_stateLabel, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hộp Đã xong" – nơi thẻ hoàn tất trượt vào.
class _DoneTray extends StatelessWidget {
  const _DoneTray({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final done = plan.finished;
    return Semantics(
      label: '${S.doneBox}: ${plan.doneCount} việc',
      child: Container(
        padding: const EdgeInsets.all(Gap.m),
        decoration: BoxDecoration(
          color: AppColors.accentBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                const SizedBox(width: Gap.s),
                Text('${S.doneBox} (${plan.doneCount})',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
            if (done.isNotEmpty) ...[
              const SizedBox(height: Gap.s),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final d in done)
                    Tooltip(
                      message: d.activity.title,
                      child: Opacity(
                        opacity: 0.75,
                        child: Pictogram(
                          iconKey: d.activity.iconKey,
                          imageRef: d.activity.imageRef,
                          size: 40,
                          background: Colors.white,
                          radius: 10,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chế độ "Cả ngày".
class _FullDayView extends StatelessWidget {
  const _FullDayView({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    final current = plan.current;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.l),
      children: [
        if (current != null) ...[
          _NowCard(item: current),
          const SizedBox(height: Gap.l),
        ] else ...[
          _UndeterminedNotice(plan: plan),
          const SizedBox(height: Gap.m),
        ],
        for (final item in plan.items)
          if (!identical(item, current))
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: _ActivityRow(item: item, dense: true),
            ),
      ],
    );
  }
}

/// Dải thông báo thay đổi lịch – tĩnh, không âm thanh, không hoạt ảnh (UC-CH-03).
class _ChangeBanner extends StatelessWidget {
  const _ChangeBanner({required this.plan});
  final DayPlan plan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
      child: Material(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showChanges(context, plan),
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Row(
              children: const [
                Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                SizedBox(width: Gap.s),
                Expanded(
                  child: Text('Hôm nay lịch có thay đổi. Chạm để xem.',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showChanges(BuildContext context, DayPlan plan) {
  final changed = plan.changed;
  final kept = plan.items.where((i) => !i.isChanged).toList();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      builder: (ctx, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.all(Gap.m),
        children: [
          const Text('Phần thay đổi',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.s),
          for (final i in changed)
            Padding(
              padding: const EdgeInsets.only(bottom: Gap.s),
              child: _ActivityRow(item: i, dense: true),
            ),
          const SizedBox(height: Gap.m),
          const Text('Phần giữ nguyên',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.s),
          for (final i in kept)
            ListTile(
              leading: Pictogram(
                  iconKey: i.activity.iconKey,
                  imageRef: i.activity.imageRef,
                  size: 40),
              title: Text(i.activity.title),
            ),
        ],
      ),
    ),
  );
}

final _detailGuard = TapGuard();

/// Chi tiết hoạt động (FR-M1-08): hình lớn, có thể nghe tên nếu bật.
void _openDetail(BuildContext context, PlanItem item) {
  if (!_detailGuard.allow()) return;
  final a = item.activity;
  final settings = context.read<SettingsController>().value;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Pictogram(
                iconKey: a.iconKey,
                imageRef: a.imageRef,
                size: 160,
                background: AppColors.cream),
            const SizedBox(height: Gap.m),
            Text(a.title,
                style:
                    const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            if (a.subtitle.isNotEmpty || a.optionalTime != null)
              Text(
                [
                  if (a.optionalTime != null) a.optionalTime!,
                  if (a.subtitle.isNotEmpty) a.subtitle,
                ].join(' · '),
                style: const TextStyle(fontSize: 17, color: AppColors.muted),
              ),
            if (item.change != null) ...[
              const SizedBox(height: Gap.s),
              Pill('${item.change!.type.label}'
                  '${item.change!.message.isNotEmpty ? ': ${item.change!.message}' : ''}',
                  color: AppColors.lightBlue),
            ],
            const SizedBox(height: Gap.l),
            if (settings.canSpeak)
              OutlinedButton.icon(
                onPressed: () => _speak(context, a.title),
                icon: const Icon(Icons.volume_up_rounded),
                label: const Text('Nghe'),
              ),
            if (!item.isFinished && item.state != PlanItemState.changedOut) ...[
              const SizedBox(height: Gap.s),
              HoldToConfirmButton(
                label: S.done,
                holdLabel: S.holdToFinish,
                requireHold: settings.doneNeedsHold,
                onConfirmed: () {
                  Navigator.pop(ctx);
                  _markDone(context, item);
                },
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.read<ScheduleController>().markLater(a.id);
                },
                child: const Text(S.later),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(S.back),
            ),
          ],
        ),
      ),
    ),
  );
}
