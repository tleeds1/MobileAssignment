import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/settings_controller.dart';
import 'caregiver/pin_screen.dart';
import 'caregiver/settings_screen.dart';

/// UC-CG-01 – chào mừng lần đầu. Có thể bỏ qua để dùng cấu hình tối giản.
/// Không hỏi tên đầy đủ, ngày sinh, địa chỉ hay chẩn đoán.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Gap.l),
          children: [
            const SizedBox(height: Gap.l),
            const Icon(Icons.wb_sunny_rounded,
                size: 80, color: AppColors.primary),
            const SizedBox(height: Gap.m),
            const Text('My Little Day',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            const SizedBox(height: Gap.s),
            const Text(
              'Hỗ trợ trẻ theo dõi lịch trong ngày, thể hiện nhu cầu bằng hình '
              'ảnh và làm quen trước với sự kiện mới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: Gap.l),
            const _Point(
              icon: Icons.child_care_rounded,
              text: 'Giao diện của trẻ có 4 khu vực: Lịch, Giao tiếp, Cảm xúc, Truyện.',
            ),
            const _Point(
              icon: Icons.touch_app_rounded,
              text:
                  'Để mở Góc người chăm sóc: NHẤN GIỮ tiêu đề ở đầu màn hình (ví dụ '
                  '"Lịch của con") khoảng 3 giây, rồi nhập mã PIN. Trẻ không thấy nút cài đặt.',
            ),
            const _Point(
              icon: Icons.lock_outline_rounded,
              text:
                  'Dữ liệu lưu trên máy này. Ứng dụng không cần tên, ngày sinh hay hồ sơ chẩn đoán của trẻ.',
            ),
            const _Point(
              icon: Icons.medical_information_outlined,
              text:
                  'Đây là công cụ hỗ trợ sinh hoạt và giao tiếp, không phải sản phẩm y tế và không thay thế chuyên gia.',
            ),
            const SizedBox(height: Gap.l),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    const PinScreen(afterUnlock: SettingsScreen(onboarding: true)),
              )),
              child: const Text('Thiết lập ngay'),
            ),
            const SizedBox(height: Gap.s),
            OutlinedButton(
              onPressed: () {
                final s = context.read<SettingsController>();
                s.update(s.value.copyWith(onboardingDone: true));
              },
              child: const Text('Bỏ qua, dùng cấu hình tối giản'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.m),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: Gap.m),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
          ],
        ),
      );
}
