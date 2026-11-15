import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/app_services.dart';
import '../../state/caregiver_session.dart';
import '../../state/settings_controller.dart';
import 'caregiver_guard.dart';
import 'card_editor_screen.dart';
import 'data_privacy_screen.dart';
import 'emotion_admin_screen.dart';
import 'schedule_editor_screen.dart';
import 'settings_screen.dart';
import 'story_list_screen.dart';

/// Bảng điều khiển M5 (UC-CG-03). Ngôn từ mô tả dữ kiện, ví dụ
/// "4 hoạt động được đánh dấu hoàn tất hôm nay" – không "trẻ đã hợp tác tốt",
/// không màu đỏ hay cảnh báo khi thiếu dữ liệu (FR-M5-07).
class CaregiverHome extends StatefulWidget {
  const CaregiverHome({super.key});

  @override
  State<CaregiverHome> createState() => _CaregiverHomeState();
}

class _Summary {
  _Summary(this.doneToday, this.done7, this.checkins, this.usage, this.audit);
  final int doneToday;
  final int done7;
  final List<EmotionEntry> checkins;
  final List<CardUsage> usage;
  final Map<String, String> audit;
}

class _CaregiverHomeState extends State<CaregiverHome> {
  late Future<_Summary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = _load();
  }

  Future<_Summary> _load() async {
    final svc = context.read<AppServices>();
    final settings = context.read<SettingsController>().value;
    final today = LocalDate.today();
    final weekAgo = LocalDate.addDays(today, -6);
    final from = LocalDate.isoOf(DateTime.now().subtract(const Duration(days: 7)));
    return _Summary(
      await svc.scheduleRepo.countDone(today, today),
      await svc.scheduleRepo.countDone(weekAgo, today),
      settings.emotionHistoryEnabled
          ? await svc.emotionRepo.entries(limit: 5)
          : const [],
      settings.cardUsageLogEnabled
          ? await svc.cardRepo.usageSince(from)
          : const [],
      await svc.settingsRepo.auditMetadata(),
    );
  }

  void _open(Widget page) {
    Navigator.of(context)
        .push(caregiverRoute(page))
        .then((_) => setState(() => _summary = _load()));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Góc người chăm sóc'),
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          FutureBuilder<_Summary>(
            future: _summary,
            builder: (context, snap) {
              final s = snap.data;
              return Container(
                margin: const EdgeInsets.all(Gap.m),
                padding: const EdgeInsets.all(Gap.m),
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: s == null
                    ? const LinearProgressIndicator()
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tổng quan',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: Gap.s),
                          Text(
                              '${s.doneToday} hoạt động được đánh dấu hoàn tất hôm nay.'),
                          Text(
                              '${s.done7} hoạt động được đánh dấu hoàn tất trong 7 ngày qua.'),
                          const SizedBox(height: Gap.s),
                          if (settings.emotionHistoryEnabled) ...[
                            Text(s.checkins.isEmpty
                                ? 'Chưa có lựa chọn check-in nào được lưu.'
                                : 'Check-in gần đây: ${s.checkins.map((e) => e.selectedLabel).join(', ')}.'),
                          ] else
                            const Text('Lưu lịch sử check-in: đang tắt.'),
                          if (settings.cardUsageLogEnabled) ...[
                            const SizedBox(height: Gap.s),
                            Text(s.usage.isEmpty
                                ? 'Chưa có lượt dùng thẻ nào được ghi trong 7 ngày.'
                                : 'Thẻ được chạm nhiều nhất 7 ngày qua: '
                                    '${s.usage.take(3).map((u) => '${u.label} (${u.count})').join(', ')}.'),
                          ],
                          const SizedBox(height: Gap.s),
                          const Text(
                            'Số liệu chỉ mô tả những gì ứng dụng ghi nhận; không phải đánh giá hay chẩn đoán.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ),
              );
            },
          ),
          _MenuTile(
            icon: Icons.calendar_month_rounded,
            title: 'Lịch & hoạt động',
            subtitle: 'Thêm, sửa, sắp xếp; báo thay đổi hôm nay',
            onTap: () => _open(const ScheduleEditorScreen()),
          ),
          _MenuTile(
            icon: Icons.grid_view_rounded,
            title: 'Thẻ giao tiếp',
            subtitle: 'Nhãn, hình, nhóm màu, thẻ ưu tiên, ảnh gia đình',
            onTap: () => _open(const CardEditorScreen()),
          ),
          _MenuTile(
            icon: Icons.auto_stories_rounded,
            title: 'Câu chuyện xã hội',
            subtitle: 'Tạo với AI hoặc mẫu, chỉnh sửa và duyệt',
            onTap: () => _open(const StoryListScreen()),
          ),
          _MenuTile(
            icon: Icons.sentiment_satisfied_alt_rounded,
            title: 'Check-in cảm xúc',
            subtitle: 'Lựa chọn hiển thị, ảnh thật, lịch sử',
            onTap: () => _open(const EmotionAdminScreen()),
          ),
          _MenuTile(
            icon: Icons.tune_rounded,
            title: 'Thiết lập cho con',
            subtitle: 'Cách hiển thị, giọng đọc, chuyển động, khóa tập trung',
            onTap: () => _open(const SettingsScreen()),
          ),
          _MenuTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Dữ liệu & quyền riêng tư',
            subtitle: 'AI, lưu giữ, xuất bản sao, xóa, đổi PIN',
            onTap: () => _open(const DataPrivacyScreen()),
          ),
          const SizedBox(height: Gap.l),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: OutlinedButton.icon(
              onPressed: () => context.read<CaregiverSession>().lock(),
              icon: const Icon(Icons.child_care_rounded),
              label: const Text('Quay về giao diện trẻ'),
            ),
          ),
          FutureBuilder<_Summary>(
            future: _summary,
            builder: (_, snap) => Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: Text(
                snap.data == null
                    ? ''
                    : 'Phiên bản ${snap.data!.audit['appVersion'] ?? '-'} · '
                        'lược đồ ${snap.data!.audit['schemaVersion'] ?? '-'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 4),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: Gap.m, vertical: 6),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Icon(icon, color: AppColors.primary, size: 32),
          title: Text(title,
              style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}
