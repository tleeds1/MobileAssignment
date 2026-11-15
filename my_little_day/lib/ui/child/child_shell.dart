import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/tap_guard.dart';
import '../../core/theme.dart';
import '../../state/schedule_controller.dart';
import '../../state/settings_controller.dart';
import '../caregiver/pin_screen.dart';
import 'communication_screen.dart';
import 'emotion_screen.dart';
import 'quick_help_sheet.dart';
import 'schedule_screen.dart';
import 'stories_screen.dart';

/// Khung giao diện trẻ (Mục 5.1): bốn khu vực cố định trên thanh điều hướng
/// dưới. Góc người chăm sóc KHÔNG có tab (BR-11) – chỉ mở bằng cách nhấn giữ
/// tiêu đề 3 giây rồi nhập PIN.
class ChildShell extends StatefulWidget {
  const ChildShell({super.key, this.preview = false});

  /// Bản xem trước trong khu vực người chăm sóc: tắt lối vào bí mật.
  final bool preview;

  @override
  State<ChildShell> createState() => _ChildShellState();
}

class _ChildShellState extends State<ChildShell> with WidgetsBindingObserver {
  int _index = 0;

  /// Chống đổi tab liên tục (visual stimming): tối thiểu 0,8 giây giữa hai
  /// lần đổi tab; chuyển tab không có hiệu ứng nhấp nháy.
  final _tabGuard = TapGuard(interval: const Duration(milliseconds: 800));
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // BR-09: kiểm tra chuyển ngày theo đồng hồ thiết bị.
    _dayTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      context.read<ScheduleController>().ensureToday();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<ScheduleController>().ensureToday();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  void _openCaregiver() {
    if (widget.preview) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PinScreen()),
    );
  }

  void _select(int i) {
    if (i == _index) return;
    if (!_tabGuard.allow()) return;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final pages = [
      ScheduleScreen(onOpenCaregiver: _openCaregiver),
      CommunicationScreen(onOpenCaregiver: _openCaregiver),
      EmotionScreen(
        onOpenCaregiver: _openCaregiver,
        onOpenTalk: () => setState(() => _index = 1),
      ),
      StoriesScreen(onOpenCaregiver: _openCaregiver),
    ];

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            IndexedStack(index: _index, children: pages),
            // Nút trợ giúp nổi ở góc trên – tránh vùng dễ trượt tay xuống
            // thanh điều hướng (góp ý M1). Ẩn ở tab Giao tiếp vì thẻ đã ở đó.
            if (_index != 1)
              const Positioned(top: 8, right: 8, child: QuickHelpButton()),
          ],
        ),
      ),
      bottomNavigationBar: settings.focusLock
          ? null // Chế độ khóa tập trung: ẩn thanh điều hướng.
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: _select,
              height: 76,
              backgroundColor: AppColors.background,
              animationDuration: Duration.zero,
              labelBehavior:
                  NavigationDestinationLabelBehavior.alwaysShow,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today),
                  label: S.tabSchedule,
                ),
                NavigationDestination(
                  icon: Icon(Icons.chat_bubble_outline_rounded),
                  selectedIcon: Icon(Icons.chat_bubble_rounded),
                  label: S.tabTalk,
                ),
                NavigationDestination(
                  icon: Icon(Icons.sentiment_satisfied_outlined),
                  selectedIcon: Icon(Icons.sentiment_satisfied_rounded),
                  label: S.tabFeelings,
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded),
                  label: S.tabStories,
                ),
              ],
            ),
    );
  }
}
