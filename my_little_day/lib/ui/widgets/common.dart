import 'package:flutter/material.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import 'secret_hold.dart';

/// Tiêu đề màn hình của trẻ. Nếu có [onSecret], tiêu đề là lối vào bí mật.
class ChildHeader extends StatelessWidget {
  const ChildHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onSecret,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onSecret;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    Widget t = Text(
      title,
      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    );
    if (onSecret != null) t = SecretHold(onTriggered: onSecret!, child: t);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m + 4, Gap.m, Gap.m, Gap.s),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: t),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.muted)),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.cream, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.text),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppColors.primary.withOpacity(0.6)),
            const SizedBox(height: Gap.m),
            Text(title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            if (hint != null) ...[
              const SizedBox(height: Gap.s),
              Text(hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
            ],
            if (action != null) ...[
              const SizedBox(height: Gap.m),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Hộp thoại xác nhận cho thao tác xóa/đặt lại (BR-08): nêu rõ phạm vi và
/// hậu quả. Với [typeToConfirm], người dùng phải gõ đúng chữ → tránh chạm nhầm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Xác nhận',
  bool destructive = false,
  String? typeToConfirm,
}) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final canConfirm =
            typeToConfirm == null || controller.text.trim() == typeToConfirm;
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (typeToConfirm != null) ...[
                const SizedBox(height: Gap.m),
                Text('Gõ "$typeToConfirm" để xác nhận:'),
                const SizedBox(height: Gap.s),
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              style: destructive
                  ? ElevatedButton.styleFrom(
                      backgroundColor: FitzgeraldColors.urgent,
                      minimumSize: const Size(48, 44))
                  : ElevatedButton.styleFrom(minimumSize: const Size(48, 44)),
              onPressed: canConfirm ? () => Navigator.pop(ctx, true) : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return ok == true;
}

/// Bảng chọn biểu tượng cho người chăm sóc.
Future<String?> pickIcon(BuildContext context,
    {required List<String> keys, String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: GridView.count(
        crossAxisCount: 5,
        padding: const EdgeInsets.all(Gap.m),
        shrinkWrap: true,
        children: [
          for (final k in keys)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => Navigator.pop(ctx, k),
              child: Container(
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: k == selected ? AppColors.accentBg : null,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(IconCatalog.of(k),
                    size: 32, color: AppColors.primary),
              ),
            ),
        ],
      ),
    ),
  );
}

void showInfo(BuildContext context, String message, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), action: action));
}
