import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Nút "Xong rồi" có tính cơ học (góp ý M1):
/// - Giữ ngón tay ~1 giây, thanh tiến trình chạy như công tắc gạt → chống chạm
///   nhầm/gõ liên thanh. Thả sớm thì hủy, không có âm báo lỗi.
/// - Có bóng đổ + viền đậm để tạo chiều sâu, thu hút ánh nhìn.
/// - Khi [requireHold] = false: chạm một lần là xong (cho trẻ khó giữ lâu).
/// - Với trình đọc màn hình, thao tác chạm kép luôn kích hoạt được (Mục 5.4).
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.onConfirmed,
    this.holdLabel,
    this.requireHold = true,
    this.holdDuration = const Duration(milliseconds: 900),
    this.icon = Icons.check_rounded,
    this.semanticsLabel,
    this.haptics = false,
  });

  final String label;
  final String? holdLabel;
  final VoidCallback onConfirmed;
  final bool requireHold;
  final Duration holdDuration;
  final IconData icon;
  final String? semanticsLabel;
  final bool haptics;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.holdDuration)
        ..addStatusListener((s) {
          if (s == AnimationStatus.completed) _fire();
        });
  bool _fired = false;

  void _fire() {
    if (_fired) return;
    _fired = true;
    if (widget.haptics) HapticFeedback.mediumImpact();
    widget.onConfirmed();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _c.reset();
        _fired = false;
      }
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const textStyle = TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.w800,
    );
    return Semantics(
      button: true,
      label: widget.semanticsLabel ?? widget.label,
      onTap: _fire,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: widget.requireHold ? (_) => _c.forward() : null,
        onTapUp: widget.requireHold
            ? (_) {
                if (!_fired) _c.reverse();
              }
            : null,
        onTapCancel: widget.requireHold
            ? () {
                if (!_fired) _c.reverse();
              }
            : null,
        onTap: widget.requireHold ? null : _fire,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final pressed = _c.value > 0;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: 64,
              transform: Matrix4.translationValues(0, pressed ? 3 : 0, 0),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF1B4D42), width: 2),
                boxShadow: pressed
                    ? const []
                    : const [
                        BoxShadow(
                            color: Color(0xFF1B4D42),
                            offset: Offset(0, 4),
                            blurRadius: 0),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    // Thanh "gạt công tắc" chạy từ trái sang phải khi giữ.
                    FractionallySizedBox(
                      widthFactor: _c.value,
                      child: Container(color: const Color(0xFF3E8F7C)),
                    ),
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(widget.icon, color: Colors.white, size: 28),
                          const SizedBox(width: 8),
                          Text(
                            pressed && widget.requireHold
                                ? (widget.holdLabel ?? widget.label)
                                : widget.label,
                            style: textStyle,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
