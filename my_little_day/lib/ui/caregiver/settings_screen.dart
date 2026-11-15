import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/tts_service.dart';
import '../../state/caregiver_session.dart';
import '../../state/schedule_controller.dart';
import '../../state/settings_controller.dart';
import '../child/child_shell.dart';
import '../widgets/common.dart';
import 'caregiver_guard.dart';

/// UI-08 / UC-CG-01 – Thiết lập cho con (Hình 10).
/// Mọi thay đổi chỉ áp dụng khi bấm "Lưu"; có bản xem trước phản ánh đúng
/// cấu hình đang chọn. Không hỏi thông tin định danh hay chẩn đoán.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onboarding = false});

  /// Lần dùng đầu: lưu xong thì đánh dấu đã thiết lập và về giao diện trẻ.
  final bool onboarding;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _s = context.read<SettingsController>().value;
  late final _name = TextEditingController(text: _s.preferredName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(AppSettings next) => setState(() => _s = next);

  Future<void> _save() async {
    var next = _s.copyWith(
      preferredName: _name.text.trim().isEmpty ? 'con' : _name.text.trim(),
    );
    if (widget.onboarding) next = next.copyWith(onboardingDone: true);
    final session = context.read<CaregiverSession>();
    session.timeout = Duration(minutes: next.sessionTimeoutMinutes);
    final schedule = context.read<ScheduleController>();
    await context.read<SettingsController>().update(next);
    await schedule.load(); // áp dụng ngay cách xác định "Bây giờ"
    if (!mounted) return;
    if (widget.onboarding) {
      session.lock(); // về giao diện trẻ
    } else {
      showInfo(context, 'Đã lưu thiết lập.');
      Navigator.pop(context);
    }
  }

  void _preview() {
    final previewCtrl = SettingsController.preview(
      _s.copyWith(preferredName: _name.text.trim()),
    );
    Navigator.of(context).push(caregiverRoute(
      ChangeNotifierProvider<SettingsController>.value(
        value: previewCtrl,
        child: Scaffold(
          appBar: AppBar(title: const Text('Xem trước giao diện trẻ')),
          body: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaleFactor: _s.textScale),
            child: const ChildShell(preview: true),
          ),
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final tts = context.watch<SpeechService>();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.onboarding ? 'Thiết lập lần đầu' : 'Thiết lập cho con'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          if (widget.onboarding)
            const InfoNote(
              'Các lựa chọn dưới đây có thể đổi lại bất cứ lúc nào. Ứng dụng '
              'không cần tên đầy đủ, ngày sinh hay hồ sơ chẩn đoán của trẻ.',
            ),
          const SectionTitle('Cách hiển thị lịch'),
          SectionCard(children: [
            for (final m in ScheduleViewMode.values)
              RadioListTile<ScheduleViewMode>(
                value: m,
                groupValue: _s.scheduleViewMode,
                onChanged: (v) => _set(_s.copyWith(scheduleViewMode: v)),
                title: Text(_modeTitle(m)),
                subtitle: Text(_modeHint(m)),
              ),
            SwitchListTile(
              value: _s.autoTimeCurrent,
              onChanged: (v) => _set(_s.copyWith(autoTimeCurrent: v)),
              title: const Text('Tự xác định "Bây giờ" theo giờ'),
              subtitle: const Text(
                  'Chỉ áp dụng khi mọi hoạt động còn lại đều có giờ. '
                  'Nếu tắt, ứng dụng đi theo thứ tự đã sắp xếp.'),
            ),
            SwitchListTile(
              value: _s.doneNeedsHold,
              onChanged: (v) => _set(_s.copyWith(doneNeedsHold: v)),
              title: const Text('Nút "Xong rồi" cần giữ 1 giây'),
              subtitle: const Text('Tránh chạm nhầm khi trẻ gõ liên tục.'),
            ),
          ]),
          const SectionTitle('Giao tiếp bằng hình ảnh'),
          SectionCard(children: [
            ListTile(
              title: const Text('Số thẻ trên một màn hình'),
              subtitle: const Text(
                  'Thứ tự thẻ luôn giữ nguyên; chỉ số thẻ mỗi trang thay đổi.'),
              trailing: Wrap(
                spacing: 6,
                children: [
                  for (final n in const [4, 6, 8])
                    ChoiceChip(
                      label: Text('$n'),
                      selected: _s.cardsPerScreen == n,
                      onSelected: (_) => _set(_s.copyWith(cardsPerScreen: n)),
                    ),
                ],
              ),
            ),
            SwitchListTile(
              value: _s.sentenceStripEnabled,
              onChanged: (v) => _set(_s.copyWith(sentenceStripEnabled: v)),
              title: const Text('Thanh ghép câu'),
              subtitle: const Text(
                  'Ghép nhiều thẻ thành câu, ví dụ "Con + muốn + uống + nước cam".'),
            ),
            SwitchListTile(
              value: _s.showLabels,
              onChanged: (v) => _set(_s.copyWith(showLabels: v)),
              title: const Text('Hiện nhãn chữ'),
            ),
          ]),
          const SectionTitle('Hỗ trợ cảm giác & tiếp cận'),
          SectionCard(children: [
            SwitchListTile(
              value: _s.ttsEnabled,
              onChanged: (v) => _set(_s.copyWith(ttsEnabled: v)),
              title: const Text('Giọng đọc'),
              subtitle: Text(tts.available
                  ? 'Chỉ đọc khi trẻ chạm; không tự phát khi mở màn hình.'
                  : 'Máy chưa có giọng đọc tiếng Việt – trẻ vẫn dùng được bằng hình và chữ.'),
            ),
            if (_s.ttsEnabled && tts.available)
              ListTile(
                title: const Text('Tốc độ đọc'),
                subtitle: Slider(
                  value: _s.ttsRate,
                  min: 0.25,
                  max: 0.7,
                  divisions: 9,
                  onChanged: (v) => _set(_s.copyWith(ttsRate: v)),
                ),
                trailing: IconButton(
                  tooltip: 'Nghe thử',
                  icon: const Icon(Icons.volume_up_rounded),
                  onPressed: () => tts.speak('Con muốn uống nước',
                      rate: _s.ttsRate),
                ),
              ),
            SwitchListTile(
              value: _s.quietMode,
              onChanged: (v) => _set(_s.copyWith(quietMode: v)),
              title: const Text('Chế độ yên tĩnh'),
              subtitle: const Text('Tắt mọi âm thanh và rung; chỉ dùng hình và chữ.'),
            ),
            SwitchListTile(
              value: _s.vibrationEnabled,
              onChanged: (v) => _set(_s.copyWith(vibrationEnabled: v)),
              title: const Text('Rung nhẹ khi hoàn tất'),
            ),
            SwitchListTile(
              value: _s.reduceMotion,
              onChanged: (v) => _set(_s.copyWith(reduceMotion: v)),
              title: const Text('Giảm chuyển động'),
            ),
            ListTile(
              title: Text('Cỡ chữ: ${(_s.textScale * 100).round()}%'),
              subtitle: Slider(
                value: _s.textScale,
                min: 1.0,
                max: 1.3,
                divisions: 6,
                onChanged: (v) => _set(_s.copyWith(textScale: v)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.m),
              child: TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Cách xưng hô hiển thị',
                  helperText: 'Ví dụ: "con", "bé". Không cần nhập tên thật.',
                ),
              ),
            ),
            const SizedBox(height: Gap.m),
          ]),
          const SectionTitle('Tập trung & an toàn'),
          SectionCard(children: [
            SwitchListTile(
              value: _s.focusLock,
              onChanged: (v) => _set(_s.copyWith(focusLock: v)),
              title: const Text('Khóa màn hình tập trung'),
              subtitle: const Text(
                  'Ẩn thanh điều hướng của trẻ; nút trợ giúp nổi vẫn hiển thị. '
                  'Có thể kết hợp Guided Access (iOS) / Ghim màn hình (Android).'),
            ),
            SwitchListTile(
              value: _s.supportSuggestionEnabled,
              onChanged: (v) => _set(_s.copyWith(supportSuggestionEnabled: v)),
              title: const Text('Gợi ý hỗ trợ sau check-in'),
              subtitle: const Text(
                  'Khi trẻ chọn ví dụ "Khó chịu", gợi ý thẻ Nghỉ / Giúp con / Thở chậm.'),
            ),
            ListTile(
              title: const Text('Tự khóa khu vực quản lý sau'),
              trailing: DropdownButton<int>(
                value: _s.sessionTimeoutMinutes,
                items: const [2, 5, 10]
                    .map((m) => DropdownMenuItem(
                        value: m, child: Text('$m phút')))
                    .toList(),
                onChanged: (v) =>
                    _set(_s.copyWith(sessionTimeoutMinutes: v)),
              ),
            ),
          ]),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.all(Gap.m),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _preview,
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Xem trước'),
                ),
              ),
              const SizedBox(width: Gap.m),
              Expanded(
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(widget.onboarding ? 'Hoàn tất' : 'Lưu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _modeTitle(ScheduleViewMode m) {
    switch (m) {
      case ScheduleViewMode.single:
        return 'Một việc';
      case ScheduleViewMode.nowNext:
        return 'Bây giờ – Tiếp theo';
      case ScheduleViewMode.fullDay:
        return 'Cả ngày';
    }
  }

  String _modeHint(ScheduleViewMode m) {
    switch (m) {
      case ScheduleViewMode.single:
        return 'Chỉ hiện việc đang làm.';
      case ScheduleViewMode.nowNext:
        return 'Hai việc: hiện tại và kế tiếp.';
      case ScheduleViewMode.fullDay:
        return 'Toàn bộ danh sách trong ngày.';
    }
  }
}
