import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../domain/story_validator.dart';
import '../../services/local_story_templates.dart';
import '../../services/story_api_client.dart';
import '../../state/settings_controller.dart';
import '../../state/story_controller.dart';
import '../widgets/common.dart';
import 'caregiver_guard.dart';
import 'story_editor_screen.dart';

/// UC-CG-02 – Nhập bối cảnh và nhận bản nháp (AI hoặc mẫu cục bộ).
///
/// - Cảnh báo không nhập tên/địa chỉ/trường; phát hiện sơ bộ dữ liệu nhận diện.
/// - Giải thích rõ dữ liệu nào được gửi, cho ai, để làm gì TRƯỚC khi gửi.
/// - Lỗi mạng/hết giờ/dịch vụ: giữ nguyên nội dung đã nhập, đề xuất mẫu hoặc
///   tự soạn; không ảnh hưởng phân hệ khác (BR-06, NFR-12).
class StoryCreateScreen extends StatefulWidget {
  const StoryCreateScreen({super.key});

  @override
  State<StoryCreateScreen> createState() => _StoryCreateScreenState();
}

class _StoryCreateScreenState extends State<StoryCreateScreen> {
  final _scenario = TextEditingController();
  final _customPref = TextEditingController();
  final List<String> _prefs = [];
  bool _busy = false;
  StoryApiException? _error;
  List<String> _inputProblems = const [];

  static const _suggested = [
    'Con muốn biết trước các bước',
    'Có thể cần nghỉ ở nơi yên tĩnh',
    'Nhạy cảm với tiếng ồn',
    'Không thích bị chạm bất ngờ',
    'Cần biết khi nào xong',
  ];

  @override
  void dispose() {
    _scenario.dispose();
    _customPref.dispose();
    super.dispose();
  }

  void _togglePref(String p) {
    setState(() {
      if (_prefs.contains(p)) {
        _prefs.remove(p);
      } else if (_prefs.length < StoryValidator.maxPrefs) {
        _prefs.add(p);
      } else {
        showInfo(context, 'Tối đa ${StoryValidator.maxPrefs} lưu ý.');
      }
    });
  }

  Future<void> _openEditor(StoryDraft draft) async {
    final ctrl = context.read<StoryController>();
    final story = await ctrl.createFromDraft(draft, _scenario.text.trim());
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(caregiverRoute(StoryEditorScreen(storyId: story.id)));
  }

  Future<void> _generateAi() async {
    final problems = StoryValidator.validateRequest(
      scenario: _scenario.text,
      language: 'vi',
      sensoryPreferences: _prefs,
    );
    setState(() => _inputProblems = problems);
    if (problems.isNotEmpty) return;

    final warnings = StoryValidator.privacyWarnings(
        [_scenario.text, ..._prefs].join(' '));
    final ok = await confirmAction(
      context,
      title: 'Gửi mô tả đến dịch vụ AI?',
      message: [
        'Sẽ gửi: mô tả sự kiện, các lưu ý cảm giác đã chọn và ngôn ngữ "vi".',
        'Không gửi: lịch, check-in, ảnh, thẻ hay bất kỳ dữ liệu nào khác trên máy.',
        'Mục đích: tạo MỘT bản nháp để bạn xem và chỉnh. Bản nháp không tự hiển thị cho trẻ.',
        'Máy chủ của ứng dụng chuyển yêu cầu đến nhà cung cấp mô hình ngôn ngữ (Anthropic Claude) và không lưu nội dung sau khi xử lý.',
        if (warnings.isNotEmpty)
          '\nLưu ý: ${warnings.join(' ')} Hãy cân nhắc xóa trước khi gửi.',
      ].join('\n'),
      confirmLabel: 'Gửi',
    );
    if (!ok || !mounted) return;

    final settings = context.read<SettingsController>().value;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await StoryApiClient(baseUrl: settings.aiServerUrl)
          .generate(scenario: _scenario.text, sensoryPreferences: _prefs);
      if (!mounted) return;
      await _openEditor(draft);
    } on StoryApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _useTemplate() async {
    final suggested = LocalStoryTemplates.suggest(_scenario.text);
    final picked = await showModalBottomSheet<LocalStoryTemplate>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(Gap.m),
              child: Text('Chọn mẫu cục bộ (không cần mạng)',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
            for (final t in LocalStoryTemplates.all)
              ListTile(
                title: Text(t.name),
                subtitle: Text('${t.steps.length} bước'),
                trailing: t.id == suggested.id
                    ? const Pill('Gợi ý', color: AppColors.accentBg)
                    : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _openEditor(picked.toDraft());
  }

  Future<void> _manual() async {
    final ctrl = context.read<StoryController>();
    final story = await ctrl.createManual(
        _scenario.text.trim().isEmpty ? 'Câu chuyện mới' : 'Câu chuyện mới');
    if (!mounted) return;
    Navigator.of(context)
        .pushReplacement(caregiverRoute(StoryEditorScreen(storyId: story.id)));
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final aiAvailable = settings.aiEnabled && settings.aiServerUrl.isNotEmpty;
    final warnings = StoryValidator.privacyWarnings(_scenario.text);
    return Scaffold(
      appBar: AppBar(title: const Text('Câu chuyện mới')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            const InfoNote(
              'Không nhập tên, địa chỉ, trường học hay thông tin sức khỏe của trẻ. '
              'Chỉ mô tả ngắn sự kiện, ví dụ: "Con sẽ đi khám tai cùng mẹ vào buổi sáng."',
              icon: Icons.shield_outlined,
            ),
            TextField(
              controller: _scenario,
              maxLength: StoryValidator.scenarioMax,
              maxLines: 3,
              onChanged: (_) => setState(() => _inputProblems = const []),
              decoration: const InputDecoration(
                labelText: 'Mô tả sự kiện',
                hintText: 'Con sẽ đi cắt tóc ở tiệm gần nhà.',
              ),
            ),
            if (warnings.isNotEmpty)
              InfoNote('Có thể chứa thông tin nhận diện: ${warnings.join(' ')}',
                  icon: Icons.warning_amber_rounded),
            for (final p in _inputProblems)
              Text(p, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.s),
            const Text('Lưu ý về cách trình bày / cảm giác (tùy chọn)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: Gap.s),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final p in {..._suggested, ..._prefs})
                  FilterChip(
                    label: Text(p),
                    selected: _prefs.contains(p),
                    onSelected: (_) => _togglePref(p),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customPref,
                    maxLength: StoryValidator.prefMax,
                    decoration:
                        const InputDecoration(labelText: 'Lưu ý khác'),
                  ),
                ),
                IconButton(
                  tooltip: 'Thêm lưu ý',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () {
                    final t = _customPref.text.trim();
                    if (t.isEmpty) return;
                    _togglePref(t);
                    _customPref.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: Gap.m),
            if (_busy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: Gap.s),
              const Text('Đang tạo bản nháp… (tối đa khoảng 15 giây)',
                  textAlign: TextAlign.center),
              const SizedBox(height: Gap.m),
            ],
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(Gap.m),
                margin: const EdgeInsets.only(bottom: Gap.m),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!.message),
              ),
            ElevatedButton.icon(
              onPressed: aiAvailable ? _generateAi : null,
              icon: const Icon(Icons.auto_awesome),
              label: Text(_error == null ? 'Tạo bản nháp bằng AI' : 'Thử lại với AI'),
            ),
            if (!aiAvailable)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'AI đang tắt hoặc chưa cấu hình máy chủ (Dữ liệu & quyền riêng tư).',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              onPressed: _useTemplate,
              icon: const Icon(Icons.description_outlined),
              label: const Text('Dùng mẫu cục bộ'),
            ),
            const SizedBox(height: Gap.s),
            OutlinedButton.icon(
              onPressed: _manual,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Tự soạn'),
            ),
          ],
        ),
      ),
    );
  }
}
