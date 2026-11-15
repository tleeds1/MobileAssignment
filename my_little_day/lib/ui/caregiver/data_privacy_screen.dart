import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/pin_service.dart';
import '../../state/app_services.dart';
import '../../state/caregiver_session.dart';
import '../../state/card_controller.dart';
import '../../state/emotion_controller.dart';
import '../../state/schedule_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/story_controller.dart';
import '../widgets/common.dart';
import 'caregiver_guard.dart';

/// UI-10 + FR-M5-05 – quyền riêng tư, AI và thao tác dữ liệu.
class DataPrivacyScreen extends StatefulWidget {
  const DataPrivacyScreen({super.key});

  @override
  State<DataPrivacyScreen> createState() => _DataPrivacyScreenState();
}

class _DataPrivacyScreenState extends State<DataPrivacyScreen> {
  late final _url = TextEditingController(
      text: context.read<SettingsController>().value.aiServerUrl);
  bool _working = false;

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  SettingsController get _settings => context.read<SettingsController>();

  Future<void> _update(AppSettings s) => _settings.update(s);

  Future<void> _toggleHistory(bool v) async {
    if (v) {
      final ok = await confirmAction(
        context,
        title: 'Bật lưu lịch sử check-in?',
        message:
            'Dữ liệu được ghi: thời điểm và nhãn trẻ CHỦ ĐỘNG chọn và xác nhận. '
            'Không ghi khi trẻ bỏ qua hoặc chọn "Con chưa biết".\n\n'
            'Lưu ở đâu: chỉ trên máy này, không gửi đi.\n'
            'Thời hạn: theo lựa chọn "Thời hạn lưu giữ" bên dưới; nếu chưa chọn, '
            'dữ liệu không tự xóa.\n'
            'Xóa: bất cứ lúc nào trong Check-in cảm xúc › Lịch sử.\n\n'
            'Ứng dụng không dùng dữ liệu này để đánh giá hay chẩn đoán.',
        confirmLabel: 'Bật',
      );
      if (!ok) return;
    }
    await _update(_settings.value.copyWith(emotionHistoryEnabled: v));
  }

  Future<void> _toggleUsage(bool v) async {
    if (v) {
      final ok = await confirmAction(
        context,
        title: 'Ghi tần suất dùng thẻ?',
        message:
            'Mỗi lần trẻ chạm một thẻ, ứng dụng ghi tên thẻ và thời điểm (trên máy này). '
            'Mục đích: giúp gia đình và nhà trị liệu xem thẻ nào hay được dùng, '
            'vào khung giờ nào, để điều chỉnh kế hoạch hỗ trợ (ví dụ IEP).\n\n'
            'Số liệu chỉ mô tả, không phải đánh giá hành vi. Có thể tắt và xóa bất cứ lúc nào.',
        confirmLabel: 'Bật',
      );
      if (!ok) return;
    }
    await _update(_settings.value.copyWith(cardUsageLogEnabled: v));
  }

  Future<void> _export() async {
    setState(() => _working = true);
    try {
      final svc = context.read<AppServices>();
      final db = svc.db.db;
      final stories = await svc.storyRepo.all();
      final data = {
        'exportedAt': LocalDate.isoNow(),
        'audit': await svc.settingsRepo.auditMetadata(),
        'settings': _settings.value.toJson(),
        'routineTemplates': await db.query('routine_templates'),
        'activities': await db.query('activities'),
        'activityCompletions': await db.query('activity_completions'),
        'scheduleChanges': await db.query('schedule_changes'),
        'cards': await db.query('cards'),
        'emotionOptions': await db.query('emotion_options'),
        'emotionEntries': await db.query('emotion_entries'),
        'stories': stories.map((s) => s.toExportJson()).toList(),
      };
      final dir = Directory(
          p.join((await getApplicationDocumentsDirectory()).path, 'exports'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(p.join(
          dir.path, 'my_little_day_${LocalDate.today()}.json'));
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(data));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Đã xuất bản sao'),
          content: Text(
              'Tệp được lưu trong vùng riêng của ứng dụng:\n${file.path}\n\n'
              'Tệp có thể chứa thông tin riêng tư của trẻ – hãy bảo quản cẩn thận '
              'và xóa khi không cần.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('Đóng')),
          ],
        ),
      );
    } catch (_) {
      if (mounted) showInfo(context, 'Chưa xuất được dữ liệu. Có thể thử lại.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _reloadAll() async {
    await Future.wait([
      _settings.reload(),
      context.read<ScheduleController>().load(),
      context.read<CardController>().load(),
      context.read<EmotionController>().load(),
      context.read<StoryController>().load(),
    ]);
  }

  Future<void> _deleteSamples() async {
    final ok = await confirmAction(
      context,
      title: 'Xóa dữ liệu minh họa?',
      message:
          'Xóa các mẫu lịch, hoạt động, thẻ và câu chuyện được đánh dấu "Minh họa". '
          'Nội dung do bạn tạo hoặc chỉnh sửa được giữ nguyên. Không thể hoàn tác.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await context.read<AppServices>().db.deleteSampleData();
    if (!mounted) return;
    await _reloadAll();
    if (mounted) showInfo(context, 'Đã xóa dữ liệu minh họa.');
  }

  Future<void> _resetAll() async {
    final ok = await confirmAction(
      context,
      title: 'Đặt lại toàn bộ dữ liệu?',
      message:
          'Sẽ xóa trên máy này: lịch, trạng thái hoàn tất, thẻ, câu chuyện, lịch sử '
          'check-in, số lượt dùng thẻ, ảnh đã thêm và mọi thiết lập. Dữ liệu minh họa '
          'được nạp lại. Mã PIN được giữ.\n\nKhông thể hoàn tác.',
      confirmLabel: 'Đặt lại',
      destructive: true,
      typeToConfirm: 'XÓA',
    );
    if (!ok || !mounted) return;
    final svc = context.read<AppServices>();
    final session = context.read<CaregiverSession>();
    await svc.db.resetAll();
    await svc.photos.deleteAll();
    if (!mounted) return;
    await _reloadAll();
    session.lock();
  }

  Future<void> _changePin() async {
    final a = TextEditingController();
    final b = TextEditingController();
    final pin = context.read<PinService>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đổi mã PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: a,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'PIN mới (4–6 số)'),
            ),
            TextField(
              controller: b,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(labelText: 'Nhập lại'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Hủy')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(48, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lưu')),
        ],
      ),
    );
    if (ok == true) {
      if (a.text != b.text || !PinService.isValidPin(a.text)) {
        if (mounted) showInfo(context, 'PIN chưa hợp lệ hoặc hai lần nhập chưa khớp.');
      } else {
        await pin.setPin(a.text);
        if (mounted) showInfo(context, 'Đã đổi mã PIN.');
      }
    }
    a.dispose();
    b.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().value;
    return Scaffold(
      appBar: AppBar(title: const Text('Dữ liệu & quyền riêng tư')),
      body: AbsorbPointer(
        absorbing: _working,
        child: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          children: [
            const InfoNote(
              'Dữ liệu của trẻ chỉ lưu trên máy này. Ứng dụng không theo dõi vị '
              'trí, không ghi âm, không chụp ảnh nền, không quảng cáo, không đồng '
              'bộ và không chia sẻ dữ liệu với ai.',
              icon: Icons.lock_outline,
            ),
            const SectionTitle('Hỗ trợ soạn câu chuyện bằng AI'),
            SectionCard(children: [
              SwitchListTile(
                value: s.aiEnabled,
                onChanged: (v) => _update(s.copyWith(aiEnabled: v)),
                title: const Text('Cho phép dùng AI'),
                subtitle: const Text(
                    'Tắt nếu không muốn gửi dữ liệu ra ngoài; mẫu cục bộ và tự soạn vẫn dùng được.'),
              ),
              Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Địa chỉ máy chủ (https://…)',
                    suffixIcon: IconButton(
                      tooltip: 'Lưu địa chỉ',
                      icon: const Icon(Icons.check),
                      onPressed: () {
                        final url = _url.text.trim();
                        if (url.isNotEmpty &&
                            !url.startsWith('https://') &&
                            !url.startsWith('http://10.0.2.2') &&
                            !url.startsWith('http://localhost')) {
                          showInfo(context,
                              'Cần dùng HTTPS (TLS) cho máy chủ thật.');
                          return;
                        }
                        _update(s.copyWith(aiServerUrl: url));
                        showInfo(context, 'Đã lưu địa chỉ máy chủ.');
                      },
                    ),
                  ),
                ),
              ),
              const ListTile(
                dense: true,
                title: Text('Dữ liệu gửi đi'),
                subtitle: Text(
                    'Chỉ mô tả sự kiện, lưu ý cảm giác bạn chọn và ngôn ngữ – sau khi bạn xác nhận từng lần.'),
              ),
              const ListTile(
                dense: true,
                title: Text('Mục đích & giới hạn'),
                subtitle: Text(
                    'Tạo một bản nháp câu chuyện. AI không chẩn đoán, không tư vấn y tế, '
                    'không tự duyệt hay đổi lịch. Khóa của nhà cung cấp AI chỉ nằm ở máy chủ.'),
              ),
            ]),
            const SectionTitle('Check-in cảm xúc'),
            SectionCard(children: [
              SwitchListTile(
                value: s.emotionHistoryEnabled,
                onChanged: _toggleHistory,
                title: const Text('Lưu lịch sử check-in'),
                subtitle: const Text('Mặc định tắt.'),
              ),
              ListTile(
                title: const Text('Thời hạn lưu giữ'),
                subtitle: const Text(
                    'Nếu chưa chọn, dữ liệu không tự xóa theo một thời hạn chưa công bố.'),
                trailing: DropdownButton<int?>(
                  value: s.dataRetentionDays,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Chưa đặt')),
                    DropdownMenuItem(value: 30, child: Text('30 ngày')),
                    DropdownMenuItem(value: 90, child: Text('90 ngày')),
                    DropdownMenuItem(value: 365, child: Text('1 năm')),
                  ],
                  onChanged: (v) async {
                    await _update(v == null
                        ? s.copyWith(clearRetention: true)
                        : s.copyWith(dataRetentionDays: v));
                    if (!mounted) return;
                    await context.read<EmotionController>().applyRetention();
                  },
                ),
              ),
            ]),
            const SectionTitle('Tần suất dùng thẻ'),
            SectionCard(children: [
              SwitchListTile(
                value: s.cardUsageLogEnabled,
                onChanged: _toggleUsage,
                title: const Text('Ghi tần suất dùng thẻ'),
                subtitle: const Text('Mặc định tắt. Hữu ích khi xem lại kế hoạch hỗ trợ.'),
              ),
              ListTile(
                leading: const Icon(Icons.bar_chart_rounded),
                title: const Text('Xem thống kê dùng thẻ'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .push(caregiverRoute(const _UsageScreen())),
              ),
            ]),
            const SectionTitle('Sao lưu & xóa'),
            SectionCard(children: [
              ListTile(
                leading: const Icon(Icons.file_download_outlined),
                title: const Text('Xuất bản sao (JSON)'),
                subtitle: const Text('Lưu trong vùng riêng của ứng dụng.'),
                onTap: _export,
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services_outlined),
                title: const Text('Xóa dữ liệu minh họa'),
                onTap: _deleteSamples,
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt_rounded,
                    color: FitzgeraldColors.urgent),
                title: const Text('Đặt lại toàn bộ dữ liệu'),
                subtitle: const Text('Cần gõ xác nhận – không thể hoàn tác.'),
                onTap: _resetAll,
              ),
              const ListTile(
                dense: true,
                title: Text('Sao lưu của hệ điều hành'),
                subtitle: Text(
                    'Ứng dụng tắt sao lưu tự động lên đám mây để dữ liệu của trẻ không bị sao chép ngoài kiểm soát.'),
              ),
            ]),
            const SectionTitle('Bảo mật'),
            SectionCard(children: [
              ListTile(
                leading: const Icon(Icons.pin_outlined),
                title: const Text('Đổi mã PIN'),
                onTap: _changePin,
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _UsageScreen extends StatelessWidget {
  const _UsageScreen();

  @override
  Widget build(BuildContext context) {
    final repo = context.read<AppServices>().cardRepo;
    final from =
        LocalDate.isoOf(DateTime.now().subtract(const Duration(days: 30)));
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê dùng thẻ (30 ngày)')),
      body: FutureBuilder<List<Object>>(
        future: Future.wait<Object>([repo.usageSince(from), repo.usageByHour(from)]),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final usage = snap.data![0] as List<CardUsage>;
          final byHour = snap.data![1] as Map<int, int>;
          if (usage.isEmpty) {
            return const EmptyState(
              icon: Icons.bar_chart_rounded,
              title: 'Chưa có dữ liệu.',
              hint: 'Dữ liệu chỉ được ghi khi bật "Ghi tần suất dùng thẻ".',
            );
          }
          final maxCount = usage.first.count;
          final maxHour = byHour.values.fold<int>(0, (a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              const Text('Số lần chạm theo thẻ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: Gap.s),
              for (final u in usage)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(children: [
                    SizedBox(width: 110, child: Text(u.label)),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: u.count / maxCount,
                        minHeight: 14,
                        color: AppColors.primary,
                        backgroundColor: AppColors.accentBg,
                      ),
                    ),
                    SizedBox(
                        width: 40,
                        child: Text(' ${u.count}', textAlign: TextAlign.end)),
                  ]),
                ),
              const SizedBox(height: Gap.l),
              const Text('Theo khung giờ',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: Gap.s),
              for (var h = 0; h < 24; h++)
                if ((byHour[h] ?? 0) > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(children: [
                      SizedBox(
                          width: 110,
                          child: Text('${h.toString().padLeft(2, '0')}:00')),
                      Expanded(
                        child: LinearProgressIndicator(
                          value: byHour[h]! / (maxHour == 0 ? 1 : maxHour),
                          minHeight: 10,
                          color: AppColors.primary,
                          backgroundColor: AppColors.accentBg,
                        ),
                      ),
                      SizedBox(
                          width: 40,
                          child:
                              Text(' ${byHour[h]}', textAlign: TextAlign.end)),
                    ]),
                  ),
              const SizedBox(height: Gap.l),
              const Text(
                'Số liệu chỉ mô tả lượt chạm được ghi nhận; không suy diễn thành '
                'đánh giá hành vi hay chẩn đoán.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: Gap.m),
              OutlinedButton(
                onPressed: () async {
                  final nav = Navigator.of(context);
                  final ok = await confirmAction(context,
                      title: 'Xóa thống kê dùng thẻ?',
                      message: 'Xóa toàn bộ lượt dùng thẻ đã ghi. Thẻ không bị xóa.',
                      confirmLabel: 'Xóa',
                      destructive: true);
                  if (ok) {
                    await repo.clearUsage();
                    nav.pop();
                  }
                },
                child: const Text('Xóa thống kê'),
              ),
            ],
          );
        },
      ),
    );
  }
}
