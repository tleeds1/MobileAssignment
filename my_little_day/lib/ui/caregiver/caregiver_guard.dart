import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/caregiver_session.dart';

/// Bọc mọi màn hình quản lý: mỗi thao tác gia hạn phiên; khi phiên hết hạn
/// hoặc bị khóa → đóng toàn bộ khu vực quản lý, quay về giao diện trẻ.
class CaregiverGuard extends StatefulWidget {
  const CaregiverGuard({super.key, required this.child});
  final Widget child;

  @override
  State<CaregiverGuard> createState() => _CaregiverGuardState();
}

class _CaregiverGuardState extends State<CaregiverGuard> {
  bool _leaving = false;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CaregiverSession>();
    if (!session.unlocked) {
      if (!_leaving) {
        _leaving = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        });
      }
      return const Scaffold(body: SizedBox.shrink());
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => session.touch(),
      child: widget.child,
    );
  }
}

Route<T> caregiverRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => CaregiverGuard(child: page));

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.l, Gap.m, Gap.s),
        child: Text(text,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: Gap.m),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: children),
      );
}

class InfoNote extends StatelessWidget {
  const InfoNote(this.text, {super.key, this.icon = Icons.info_outline});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: Gap.s),
        padding: const EdgeInsets.all(Gap.m),
        decoration: BoxDecoration(
          color: AppColors.lightBlue,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: Gap.s),
            Expanded(child: Text(text)),
          ],
        ),
      );
}
