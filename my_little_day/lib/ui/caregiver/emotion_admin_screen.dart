import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/photo_service.dart';
import '../../state/app_services.dart';
import '../../state/emotion_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'caregiver_guard.dart';

/// M3 phía người chăm sóc: cấu hình lựa chọn (kể cả ảnh thật/ảnh cơ thể),
/// xem và xóa lịch sử check-in (FR-M3-05, TC-09).
class EmotionAdminScreen extends StatelessWidget {
  const EmotionAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Check-in cảm xúc'),
          bottom: const TabBar(
            labelColor: AppColors.text,
            tabs: [Tab(text: 'Lựa chọn'), Tab(text: 'Lịch sử')],
          ),
        ),
        body: const TabBarView(children: [_OptionsTab(), _HistoryTab()]),
      ),
    );
  }
}

class _OptionsTab extends StatelessWidget {
  const _OptionsTab();

  Future<void> _edit(BuildContext context, EmotionOption o,
      {bool isNew = false}) async {
    final ctrl = context.read<EmotionController>();
    final result = await Navigator.of(context).push<EmotionOption>(
        caregiverRoute(_OptionForm(option: o, isNew: isNew)));
    if (result != null) {
      await ctrl.repo.saveOption(result);
      await ctrl.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EmotionController>();
    final options = ctrl.allOptions;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(
          context,
          EmotionOption(
            id: ctrl.repo.newId(),
            label: '',
            iconKey: 'smile',
            position: options.length,
          ),
          isNew: true,
        ),
        icon: const Icon(Icons.add),
        label: const Text('Thêm lựa chọn'),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const InfoNote(
            'Danh sách chỉ mang tính gợi ý – hãy dùng từ và hình trẻ quen. '
            'Có thể thay biểu tượng bằng ảnh thật (ví dụ ảnh nét mặt của trẻ, '
            'người đang ôm đầu, người nằm nghỉ). Ứng dụng không chấm điểm, '
            'không diễn giải lựa chọn.',
          ),
          for (final o in options)
            ListTile(
              leading: Pictogram(
                  iconKey: o.iconKey,
                  imageRef: o.imageRef,
                  size: 44,
                  background: AppColors.cream,
                  radius: 22),
              title: Text(o.label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: o.hidden ? AppColors.muted : AppColors.text)),
              subtitle: Text([
                o.kind == EmotionKind.body ? 'Cơ thể' : 'Cảm xúc',
                if (o.suggestSupport) 'Gợi ý hỗ trợ',
                if (o.hidden) 'Đang ẩn',
              ].join(' · ')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _edit(context, o),
            ),
        ],
      ),
    );
  }
}

class _OptionForm extends StatefulWidget {
  const _OptionForm({required this.option, required this.isNew});
  final EmotionOption option;
  final bool isNew;

  @override
  State<_OptionForm> createState() => _OptionFormState();
}

class _OptionFormState extends State<_OptionForm> {
  final _form = GlobalKey<FormState>();
  late EmotionOption _o = widget.option;
  late final _label = TextEditingController(text: _o.label);

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _photo(bool camera) async {
    try {
      final path =
          await context.read<AppServices>().photos.pick(camera: camera);
      if (path != null) setState(() => _o = _o.copyWith(imageRef: path));
    } on PhotoException catch (e) {
      showInfo(context, e.message);
    } catch (_) {
      showInfo(context, 'Không mở được ảnh.');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(context,
        title: 'Xóa lựa chọn?',
        message:
            'Xóa "${_o.label}" khỏi màn hình check-in. Bản ghi cũ trong lịch sử không bị ảnh hưởng.',
        confirmLabel: 'Xóa',
        destructive: true);
    if (!ok || !mounted) return;
    final ctrl = context.read<EmotionController>();
    final photos = context.read<AppServices>().photos;
    await ctrl.repo.deleteOption(_o.id);
    await photos.delete(_o.imageRef);
    await ctrl.load();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Thêm lựa chọn' : 'Sửa lựa chọn'),
        actions: [
          if (!widget.isNew)
            IconButton(
                tooltip: 'Xóa',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Center(
              child: Pictogram(
                iconKey: _o.iconKey,
                imageRef: _o.imageRef,
                size: 120,
                background: AppColors.cream,
                radius: 60,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final k = await pickIcon(context,
                        keys: IconCatalog.emotionKeys, selected: _o.iconKey);
                    if (k != null) setState(() => _o = _o.copyWith(iconKey: k));
                  },
                  icon: const Icon(Icons.emoji_symbols),
                  label: const Text('Biểu tượng'),
                ),
                TextButton.icon(
                  onPressed: () => _photo(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Ảnh'),
                ),
                TextButton.icon(
                  onPressed: () => _photo(true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp'),
                ),
                if (_o.imageRef != null)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _o = _o.copyWith(clearImage: true)),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Bỏ ảnh'),
                  ),
              ],
            ),
            TextFormField(
              controller: _label,
              maxLength: 24,
              decoration: const InputDecoration(labelText: 'Nhãn *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Cần có nhãn.' : null,
            ),
            const Text('Nhóm', style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(spacing: 8, children: [
              ChoiceChip(
                label: const Text('Cảm xúc'),
                selected: _o.kind == EmotionKind.feeling,
                onSelected: (_) => setState(
                    () => _o = _o.copyWith(kind: EmotionKind.feeling)),
              ),
              ChoiceChip(
                label: const Text('Cảm giác cơ thể'),
                selected: _o.kind == EmotionKind.body,
                onSelected: (_) =>
                    setState(() => _o = _o.copyWith(kind: EmotionKind.body)),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _o.suggestSupport,
              onChanged: (v) =>
                  setState(() => _o = _o.copyWith(suggestSupport: v)),
              title: const Text('Gợi ý hỗ trợ sau khi chọn'),
              subtitle: const Text(
                  'Mở gợi ý: thẻ Nghỉ, Giúp con, Thở chậm (trẻ có thể từ chối).'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _o.hidden,
              onChanged: (v) => setState(() => _o = _o.copyWith(hidden: v)),
              title: const Text('Tạm ẩn'),
            ),
            const SizedBox(height: Gap.m),
            ElevatedButton(
              onPressed: () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(
                    context, _o.copyWith(label: _label.text.trim()));
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();
  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  late Future<List<EmotionEntry>> _future =
      context.read<AppServices>().emotionRepo.entries();

  void _reload() => setState(
      () => _future = context.read<AppServices>().emotionRepo.entries());

  @override
  Widget build(BuildContext context) {
    final enabled =
        context.watch<SettingsController>().value.emotionHistoryEnabled;
    final repo = context.read<AppServices>().emotionRepo;
    return FutureBuilder<List<EmotionEntry>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        return ListView(
          children: [
            InfoNote(enabled
                ? 'Đang lưu lịch sử: chỉ ghi thời điểm và nhãn khi trẻ chủ động '
                    'chọn và xác nhận. Bỏ qua không tạo bản ghi.'
                : 'Lưu lịch sử đang TẮT – không có lựa chọn mới nào được ghi. '
                    'Có thể bật trong "Dữ liệu & quyền riêng tư".'),
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.all(Gap.l),
                child: Text('Chưa có bản ghi nào.',
                    textAlign: TextAlign.center),
              )
            else ...[
              for (final e in list)
                ListTile(
                  title: Text(e.selectedLabel),
                  subtitle: Text(e.localDateTime
                      .replaceFirst('T', ' ')
                      .substring(0, 16)),
                  trailing: IconButton(
                    tooltip: 'Xóa bản ghi',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await confirmAction(context,
                          title: 'Xóa bản ghi?',
                          message:
                              'Xóa lựa chọn "${e.selectedLabel}" lúc ${e.localDateTime.substring(11, 16)}.',
                          confirmLabel: 'Xóa',
                          destructive: true);
                      if (ok) {
                        await repo.deleteEntry(e.id);
                        _reload();
                      }
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(Gap.m),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('Xóa toàn bộ lịch sử check-in'),
                  onPressed: () async {
                    final ok = await confirmAction(context,
                        title: 'Xóa toàn bộ lịch sử?',
                        message:
                            'Xóa ${list.length} bản ghi check-in khỏi máy này. Không thể hoàn tác. '
                            'Lựa chọn và cài đặt không bị ảnh hưởng.',
                        confirmLabel: 'Xóa tất cả',
                        destructive: true);
                    if (ok) {
                      await repo.deleteAllEntries();
                      _reload();
                    }
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
