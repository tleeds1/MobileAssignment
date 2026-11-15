import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../domain/story_lifecycle.dart';
import '../../domain/story_validator.dart';
import '../../services/photo_service.dart';
import '../../state/app_services.dart';
import '../../state/card_controller.dart';
import '../../state/story_controller.dart';
import '../child/story_reader_screen.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'caregiver_guard.dart';
import 'story_list_screen.dart';

/// UI-06 – Xem trước, chỉnh sửa và duyệt câu chuyện.
/// Phân biệt rõ "Lưu bản nháp" và "Duyệt và cho trẻ xem".
class StoryEditorScreen extends StatefulWidget {
  const StoryEditorScreen({super.key, required this.storyId});
  final String storyId;

  @override
  State<StoryEditorScreen> createState() => _StoryEditorScreenState();
}

class _StoryEditorScreenState extends State<StoryEditorScreen> {
  SocialStory? _original;
  late SocialStory _edit;
  final _title = TextEditingController();
  final List<TextEditingController> _stepCtrls = [];

  @override
  void initState() {
    super.initState();
    _bind(context.read<StoryController>().byId(widget.storyId));
  }

  void _bind(SocialStory? s) {
    _original = s;
    if (s == null) return;
    _edit = s;
    _title.text = s.title;
    for (final c in _stepCtrls) {
      c.dispose();
    }
    _stepCtrls
      ..clear()
      ..addAll(s.steps.map((st) => TextEditingController(text: st.text)));
  }

  @override
  void dispose() {
    _title.dispose();
    for (final c in _stepCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  SocialStory _collect() {
    final steps = <StoryStep>[];
    for (var i = 0; i < _edit.steps.length; i++) {
      steps.add(_edit.steps[i]
          .copyWith(text: _stepCtrls[i].text.trim(), position: i));
    }
    return _edit.copyWith(title: _title.text.trim(), steps: steps);
  }

  bool get _dirty {
    final o = _original;
    if (o == null) return false;
    final c = _collect();
    if (c.title != o.title || c.steps.length != o.steps.length) return true;
    for (var i = 0; i < c.steps.length; i++) {
      final a = c.steps[i], b = o.steps[i];
      if (a.text != b.text ||
          a.iconKey != b.iconKey ||
          a.imageRef != b.imageRef) {
        return true;
      }
    }
    return false;
  }

  Future<SocialStory?> _saveDraft({bool quiet = false}) async {
    final o = _original!;
    final wasApproved = o.status == StoryStatus.approved;
    final dirty = _dirty;
    final saved =
        await context.read<StoryController>().saveEdit(o, _collect());
    if (!mounted) return saved;
    setState(() => _bind(saved));
    if (!quiet) {
      showInfo(
        context,
        wasApproved && dirty
            ? 'Đã lưu. Câu chuyện chuyển về bản nháp và cần duyệt lại – trẻ tạm thời không thấy.'
            : 'Đã lưu bản nháp.',
      );
    }
    return saved;
  }

  Future<void> _approve() async {
    final current = _collect();
    final problems = StoryLifecycle.approvalProblems(current);
    if (problems.isNotEmpty) {
      showInfo(context, problems.join(' '));
      return;
    }
    final ok = await confirmAction(
      context,
      title: 'Duyệt và cho trẻ xem?',
      message:
          'Câu chuyện "${current.title}" sẽ xuất hiện trong thư viện của trẻ. '
          'Bạn đã đọc lại từng bước và thấy phù hợp với con chưa?',
      confirmLabel: 'Duyệt',
    );
    if (!ok || !mounted) return;
    final ctrl = context.read<StoryController>();
    final saved = await _saveDraft(quiet: true);
    if (saved == null) return;
    try {
      final approved = await ctrl.approve(saved);
      if (!mounted) return;
      setState(() => _bind(approved));
      showInfo(context, 'Đã duyệt. Trẻ có thể xem câu chuyện này.');
    } on StoryRuleError catch (e) {
      if (mounted) showInfo(context, e.message);
    }
  }

  Future<void> _more(String action) async {
    final ctrl = context.read<StoryController>();
    final s = _original!;
    switch (action) {
      case 'archive':
        final next = await ctrl.archive(s);
        if (mounted) setState(() => _bind(next));
        break;
      case 'restore':
        final next = await ctrl.restore(s);
        if (mounted) setState(() => _bind(next));
        break;
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Xóa câu chuyện?',
          message:
              'Xóa vĩnh viễn "${s.title}" cùng ${s.steps.length} bước, ảnh đính kèm và liên kết thẻ. Không thể hoàn tác.',
          confirmLabel: 'Xóa',
          destructive: true,
        );
        if (!ok || !mounted) return;
        final photos = context.read<AppServices>().photos;
        for (final st in s.steps) {
          await photos.delete(st.imageRef);
        }
        await ctrl.delete(s);
        if (mounted) Navigator.pop(context);
        break;
    }
  }

  void _addStep() {
    if (_edit.steps.length >= StoryLifecycle.maxSteps) {
      showInfo(context, 'Tối đa ${StoryLifecycle.maxSteps} bước.');
      return;
    }
    final repo = context.read<StoryController>().repo;
    setState(() {
      _edit = _collect();
      _edit = _edit.copyWith(steps: [
        ..._edit.steps,
        StoryStep(
          id: repo.newId(),
          storyId: _edit.id,
          text: '',
          iconKey: 'smile',
          position: _edit.steps.length,
        ),
      ]);
      _stepCtrls.add(TextEditingController());
    });
  }

  void _removeStep(int i) {
    setState(() {
      _edit = _collect();
      final steps = [..._edit.steps]..removeAt(i);
      _edit = _edit.copyWith(steps: steps);
      _stepCtrls.removeAt(i).dispose();
    });
  }

  void _moveStep(int i, int delta) {
    final j = i + delta;
    if (j < 0 || j >= _edit.steps.length) return;
    setState(() {
      _edit = _collect();
      final steps = [..._edit.steps];
      final s = steps.removeAt(i);
      steps.insert(j, s);
      final c = _stepCtrls.removeAt(i);
      _stepCtrls.insert(j, c);
      _edit = _edit.copyWith(steps: steps);
    });
  }

  void _updateStep(int i, StoryStep step) {
    setState(() {
      _edit = _collect();
      final steps = [..._edit.steps];
      steps[i] = step;
      _edit = _edit.copyWith(steps: steps);
    });
  }

  Future<void> _stepPhoto(int i, bool camera) async {
    try {
      final path =
          await context.read<AppServices>().photos.pick(camera: camera);
      if (path != null) _updateStep(i, _edit.steps[i].copyWith(imageRef: path));
    } on PhotoException catch (e) {
      showInfo(context, e.message);
    } catch (_) {
      showInfo(context, 'Không mở được ảnh.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_original == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
            icon: Icons.error_outline, title: 'Không tìm thấy câu chuyện.'),
      );
    }
    final o = _original!;
    final cards = context.watch<CardController>().all;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chỉnh sửa câu chuyện'),
        actions: [
          PopupMenuButton<String>(
            onSelected: _more,
            itemBuilder: (_) => [
              if (o.status != StoryStatus.archived)
                const PopupMenuItem(value: 'archive', child: Text('Lưu trữ'))
              else
                const PopupMenuItem(
                    value: 'restore', child: Text('Khôi phục về bản nháp')),
              const PopupMenuItem(value: 'delete', child: Text('Xóa')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.m, 160),
        children: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusPill(status: o.status),
            Pill('Nguồn: ${o.source.label}', color: AppColors.lightBlue),
            if (o.approvedAt != null)
              Pill('Duyệt lúc ${o.approvedAt!.replaceFirst('T', ' ').substring(0, 16)}',
                  color: AppColors.accentBg),
          ]),
          if (o.source == StorySource.ai && o.status == StoryStatus.draft)
            const InfoNote(
              'Bản nháp do AI tạo có thể chưa đúng thực tế. Hãy đọc kỹ, chỉnh '
              'từng bước và thay hình bằng ảnh thật nếu có.',
              icon: Icons.auto_awesome,
            ),
          if (o.status == StoryStatus.approved)
            const InfoNote(
                'Câu chuyện đang hiển thị cho trẻ. Mọi chỉnh sửa nội dung sẽ đưa câu chuyện về bản nháp và cần duyệt lại.'),
          if (o.caregiverTip.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: Gap.s),
              padding: const EdgeInsets.all(Gap.m),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Ghi chú cho người chăm sóc (trẻ không thấy): '
                  '${o.caregiverTip}'),
            ),
          const SizedBox(height: Gap.m),
          TextField(
            controller: _title,
            maxLength: StoryValidator.titleMax,
            decoration: const InputDecoration(labelText: 'Tiêu đề'),
          ),
          const Text('Các bước (mỗi bước một câu ngắn)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.s),
          for (var i = 0; i < _edit.steps.length; i++) _stepCard(i),
          OutlinedButton.icon(
            onPressed: _addStep,
            icon: const Icon(Icons.add),
            label: const Text('Thêm bước'),
          ),
          const SizedBox(height: Gap.l),
          const Text('Thẻ hỗ trợ liên kết',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const Text(
              'Trẻ có thể mở thẻ này từ câu chuyện. Đổi liên kết không ảnh hưởng trạng thái duyệt.',
              style: TextStyle(color: AppColors.muted)),
          const SizedBox(height: Gap.s),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cards)
                FilterChip(
                  label: Text(c.label),
                  selected: o.linkedCardIds.contains(c.id),
                  onSelected: (v) async {
                    final ids = [...o.linkedCardIds];
                    v ? ids.add(c.id) : ids.remove(c.id);
                    final ctrl = context.read<StoryController>();
                    await ctrl.setLinks(o, ids);
                    final fresh = ctrl.byId(o.id);
                    if (mounted && fresh != null) {
                      setState(() {
                        _original = fresh;
                        _edit = _collect().copyWith(linkedCardIds: ids);
                      });
                    }
                  },
                ),
            ],
          ),
        ],
      ),
      bottomSheet: SafeArea(
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                          caregiverRoute(StoryReaderScreen(preview: _collect()))),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('Xem trước'),
                    ),
                  ),
                  const SizedBox(width: Gap.s),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _saveDraft(),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Lưu bản nháp'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Gap.s),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: o.status == StoryStatus.archived ? null : _approve,
                  icon: const Icon(Icons.verified_rounded),
                  label: Text(o.status == StoryStatus.approved && !_dirty
                      ? 'Đã duyệt'
                      : 'Duyệt và cho trẻ xem'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepCard(int i) {
    final step = _edit.steps[i];
    final warnings = StoryValidator.stepWarnings(_stepCtrls[i].text);
    return Container(
      margin: const EdgeInsets.only(bottom: Gap.s),
      padding: const EdgeInsets.all(Gap.s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Bước ${i + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                  tooltip: 'Lên',
                  onPressed: i > 0 ? () => _moveStep(i, -1) : null,
                  icon: const Icon(Icons.arrow_upward)),
              IconButton(
                  tooltip: 'Xuống',
                  onPressed: i < _edit.steps.length - 1
                      ? () => _moveStep(i, 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward)),
              IconButton(
                  tooltip: 'Xóa bước',
                  onPressed:
                      _edit.steps.length > 1 ? () => _removeStep(i) : null,
                  icon: const Icon(Icons.delete_outline)),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () async {
                  final k = await pickIcon(context,
                      keys: {
                        ...IconCatalog.storyAllowlist,
                        ...IconCatalog.activityKeys,
                      }.toList(),
                      selected: step.iconKey);
                  if (k != null) _updateStep(i, step.copyWith(iconKey: k));
                },
                child: Pictogram(
                  iconKey: step.iconKey,
                  imageRef: step.imageRef,
                  size: 64,
                  background: AppColors.lightBlue,
                ),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: TextField(
                  controller: _stepCtrls[i],
                  maxLength: StoryValidator.stepMax,
                  maxLines: 2,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                      hintText: 'Ví dụ: Con ngồi chờ cùng người lớn.'),
                ),
              ),
            ],
          ),
          Wrap(spacing: 4, children: [
            TextButton.icon(
              onPressed: () => _stepPhoto(i, false),
              icon: const Icon(Icons.photo_library_outlined, size: 18),
              label: const Text('Ảnh thật'),
            ),
            TextButton.icon(
              onPressed: () => _stepPhoto(i, true),
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: const Text('Chụp'),
            ),
            if (step.imageRef != null)
              TextButton.icon(
                onPressed: () =>
                    _updateStep(i, step.copyWith(clearImage: true)),
                icon: const Icon(Icons.hide_image_outlined, size: 18),
                label: const Text('Bỏ ảnh'),
              ),
          ]),
          for (final w in warnings)
            Text('• $w',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
