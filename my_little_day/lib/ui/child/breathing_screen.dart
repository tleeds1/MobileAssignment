import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../state/settings_controller.dart';

/// Hỗ trợ xoa dịu: vòng tròn phồng/xẹp chậm (8 giây/chu kỳ), không âm thanh,
/// không nhấp nháy. Khi bật "giảm chuyển động", chỉ hiện chữ hướng dẫn tĩnh.
class BreathingScreen extends StatefulWidget {
  const BreathingScreen({super.key});

  @override
  State<BreathingScreen> createState() => _BreathingScreenState();
}

class _BreathingScreenState extends State<BreathingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final motion = context.read<SettingsController>().value.animationsOn;
    if (motion && !_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.watch<SettingsController>().value.animationsOn;
    return Scaffold(
      backgroundColor: AppColors.lightBlue,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                iconSize: 36,
                tooltip: 'Đóng',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Expanded(
              child: Center(
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final t = motion ? _c.value : 0.5;
                    final size = 140 + 120 * t;
                    final label = !motion
                        ? 'Hít vào… Thở ra…'
                        : (_c.status == AnimationStatus.forward
                            ? 'Hít vào'
                            : 'Thở ra');
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.primary.withOpacity(0.25),
                            border: Border.all(
                                color: AppColors.primary, width: 4),
                          ),
                        ),
                        const SizedBox(height: Gap.xl),
                        Text(label,
                            style: const TextStyle(
                                fontSize: 30, fontWeight: FontWeight.w800)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
