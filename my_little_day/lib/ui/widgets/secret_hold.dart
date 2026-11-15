import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Lối vào dành cho người lớn (góp ý M5): nhấn giữ tiêu đề "Lịch của con"
/// trong [duration] (mặc định 3 giây) mới mở màn hình PIN. Không có nút
/// "Cài đặt" lộ liễu trên giao diện trẻ, không phát âm thanh hay hiệu ứng
/// nhấp nháy trong lúc giữ – chỉ một vòng tiến trình nhỏ, mờ.
///
/// Với trình đọc màn hình: có hành động tùy chỉnh "Mở Góc người chăm sóc".
class SecretHold extends StatefulWidget {
  const SecretHold({
    super.key,
    required this.child,
    required this.onTriggered,
    this.duration = const Duration(seconds: 3),
  });

  final Widget child;
  final VoidCallback onTriggered;
  final Duration duration;

  @override
  State<SecretHold> createState() => _SecretHoldState();
}

class _SecretHoldState extends State<SecretHold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) {
            _c.reset();
            widget.onTriggered();
          }
        });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        const CustomSemanticsAction(label: 'Mở Góc người chăm sóc'):
            widget.onTriggered,
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (_) => _c.forward(from: 0),
        onLongPressEnd: (_) => _c.reset(),
        onLongPressCancel: () => _c.reset(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            Positioned(
              right: -28,
              top: 4,
              child: AnimatedBuilder(
                animation: _c,
                builder: (_, __) => _c.value == 0
                    ? const SizedBox.shrink()
                    : SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          value: _c.value,
                          strokeWidth: 3,
                          color: Colors.black26,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
