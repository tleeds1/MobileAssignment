import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/photo_service.dart';
import '../../state/app_services.dart';
import '../../state/card_controller.dart';
import '../widgets/comm_card_tile.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'caregiver_guard.dart';

/// FR-M2-04..07 – quản lý thẻ giao tiếp.
class CardEditorScreen extends StatelessWidget {
  const CardEditorScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final ctrl = context.read<CardController>();
    final card = await editCard(
      context,
      CommunicationCard(
        id: ctrl.repo.newId(),
        label: '',
        position: await ctrl.repo.nextPosition(),
      ),
      isNew: true,
    );
    if (card != null) {
      await ctrl.repo.save(card);
      await ctrl.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CardController>();
    final cards = ctrl.all;
    return Scaffold(
      appBar: AppBar(title: const Text('Thẻ giao tiếp')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm thẻ'),
      ),
      body: Column(
        children: [
          const InfoNote(
            'Thứ tự trong danh sách là vị trí cố định của thẻ trên màn hình '
            'của trẻ. Đổi số thẻ mỗi màn hình (4/6/8) không làm đảo vị trí. '
            'Giữ và kéo để sắp xếp.',
          ),
          const _Legend(),
          Expanded(
            child: cards.isEmpty
                ? const EmptyState(
                    icon: Icons.grid_view_rounded,
                    title: 'Chưa có thẻ.',
                    hint: 'Bấm "Thêm thẻ" để tạo thẻ đầu tiên.')
                : ReorderableListView(
                    padding: const EdgeInsets.only(bottom: 96),
                    onReorder: (oldI, newI) async {
                      if (newI > oldI) newI -= 1;
                      final list = [...cards];
                      final moved = list.removeAt(oldI);
                      list.insert(newI, moved);
                      await ctrl.repo.reorder(list.map((c) => c.id).toList());
                      await ctrl.load();
                    },
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        ListTile(
                          key: ValueKey(cards[i].id),
                          leading: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: categoryColor(cards[i].category),
                                  width: 3),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Pictogram(
                                iconKey: cards[i].iconKey,
                                imageRef: cards[i].imageRef,
                                size: 44,
                                color: AppColors.text),
                          ),
                          title: Text('${i + 1}. ${cards[i].label}',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cards[i].hidden
                                      ? AppColors.muted
                                      : AppColors.text)),
                          subtitle: Text([
                            cards[i].category.label,
                            if (cards[i].favorite) 'Ưu tiên',
                            if (cards[i].hidden) 'Đang ẩn',
                            if (cards[i].isSample) 'Minh họa',
                          ].join(' · ')),
                          onTap: () async {
                            final photos = context.read<AppServices>().photos;
                            final edited = await editCard(context, cards[i]);
                            if (edited == null) return;
                            if (edited.imageRef != cards[i].imageRef) {
                              await photos.delete(cards[i].imageRef);
                            }
                            await ctrl.repo.save(edited);
                            await ctrl.load();
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.m),
      child: Wrap(
        spacing: 10,
        runSpacing: 4,
        children: [
          for (final c in CardCategory.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(categoryMarker(c), size: 16, color: categoryColor(c)),
                const SizedBox(width: 2),
                Text(c.label, style: const TextStyle(fontSize: 12)),
              ],
            ),
        ],
      ),
    );
  }
}

Future<CommunicationCard?> editCard(BuildContext context, CommunicationCard c,
    {bool isNew = false}) {
  return Navigator.of(context).push<CommunicationCard>(
      caregiverRoute(_CardForm(card: c, isNew: isNew)));
}

class _CardForm extends StatefulWidget {
  const _CardForm({required this.card, required this.isNew});
  final CommunicationCard card;
  final bool isNew;

  @override
  State<_CardForm> createState() => _CardFormState();
}

class _CardFormState extends State<_CardForm> {
  final _form = GlobalKey<FormState>();
  late CommunicationCard _c = widget.card;
  late final _label = TextEditingController(text: _c.label);
  late final _speech = TextEditingController(text: _c.speechText);

  @override
  void dispose() {
    _label.dispose();
    _speech.dispose();
    super.dispose();
  }

  Future<void> _photo(bool camera) async {
    try {
      final path =
          await context.read<AppServices>().photos.pick(camera: camera);
      if (path != null) setState(() => _c = _c.copyWith(imageRef: path));
    } on PhotoException catch (e) {
      showInfo(context, e.message);
    } catch (_) {
      showInfo(context, 'Không mở được ảnh. Hãy kiểm tra quyền truy cập ảnh.');
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Xóa thẻ?',
      message:
          'Xóa thẻ "${_c.label}". Liên kết của thẻ với câu chuyện và số lượt dùng đã ghi cũng bị xóa. Ảnh của thẻ sẽ bị xóa khỏi máy.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final ctrl = context.read<CardController>();
    final photos = context.read<AppServices>().photos;
    await ctrl.repo.delete(_c.id);
    await photos.delete(_c.imageRef);
    await ctrl.load();
    if (mounted) Navigator.pop(context);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _c.copyWith(label: _label.text.trim(), speechText: _speech.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'Thêm thẻ' : 'Sửa thẻ'),
        actions: [
          if (!widget.isNew)
            IconButton(
                tooltip: 'Xóa thẻ',
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
              child: SizedBox(
                width: 180,
                height: 180,
                child: CommCardTile(
                  card: _c.copyWith(label: _label.text),
                  onTap: () {},
                ),
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final k = await pickIcon(context,
                        keys: IconCatalog.cardKeys, selected: _c.iconKey);
                    if (k != null) setState(() => _c = _c.copyWith(iconKey: k));
                  },
                  icon: const Icon(Icons.emoji_symbols),
                  label: const Text('Biểu tượng'),
                ),
                TextButton.icon(
                  onPressed: () => _photo(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Ảnh gia đình'),
                ),
                TextButton.icon(
                  onPressed: () => _photo(true),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Chụp'),
                ),
                if (_c.imageRef != null)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _c = _c.copyWith(clearImage: true)),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Bỏ ảnh'),
                  ),
              ],
            ),
            const InfoNote(
              'Ảnh được lưu trong vùng riêng của ứng dụng trên máy này, không '
              'gửi đi đâu. Tránh ảnh có thông tin nhận diện không cần thiết.',
              icon: Icons.lock_outline,
            ),
            TextFormField(
              controller: _label,
              maxLength: 24,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Nhãn trên thẻ *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Cần có nhãn.' : null,
            ),
            TextFormField(
              controller: _speech,
              maxLength: 80,
              decoration: const InputDecoration(
                labelText: 'Câu đọc/hiển thị (tùy chọn)',
                hintText: 'Ví dụ: Con muốn uống nước',
              ),
            ),
            const SizedBox(height: Gap.s),
            const Text('Nhóm (mã màu Fitzgerald)',
                style: TextStyle(fontWeight: FontWeight.w700)),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final cat in CardCategory.values)
                  ChoiceChip(
                    avatar: Icon(categoryMarker(cat),
                        size: 16, color: categoryColor(cat)),
                    label: Text(cat.label),
                    selected: _c.category == cat,
                    onSelected: (_) =>
                        setState(() => _c = _c.copyWith(category: cat)),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _c.favorite,
              onChanged: (v) => setState(() => _c = _c.copyWith(favorite: v)),
              title: const Text('Thẻ ưu tiên'),
              subtitle: const Text(
                  'Hiện trong nút trợ giúp nổi – mở được trong 2 thao tác.'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _c.hidden,
              onChanged: (v) => setState(() => _c = _c.copyWith(hidden: v)),
              title: const Text('Tạm ẩn với trẻ'),
              subtitle: const Text(
                  'Thẻ ẩn vẫn giữ vị trí trong danh sách để không xáo trộn.'),
            ),
            const SizedBox(height: Gap.m),
            ElevatedButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}
