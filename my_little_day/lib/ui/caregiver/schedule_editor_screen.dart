import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/date_utils.dart';
import '../../core/icon_catalog.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../data/repositories/schedule_repository.dart';
import '../../services/photo_service.dart';
import '../../state/app_services.dart';
import '../../state/card_controller.dart';
import '../../state/schedule_controller.dart';
import '../../state/story_controller.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'caregiver_guard.dart';

/// UC-CG-03 / FR-M1-05..07, FR-M1-12 – quản lý lịch.
class ScheduleEditorScreen extends StatelessWidget {
  const ScheduleEditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lịch & hoạt động'),
          bottom: const TabBar(
            labelColor: AppColors.text,
            tabs: [
              Tab(text: 'Theo ngày'),
              Tab(text: 'Mẫu lịch lặp lại'),
            ],
          ),
        ),
        body: const TabBarView(children: [_DayTab(), _TemplatesTab()]),
      ),
    );
  }
}

// ===========================================================================
// Theo ngày: xem/chỉnh lịch của một ngày cụ thể, báo thay đổi
// ===========================================================================

class _DayTab extends StatefulWidget {
  const _DayTab();
  @override
  State<_DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<_DayTab> {
  String _date = LocalDate.today();
  List<Activity> _items = const [];
  Map<String, ActivityCompletion> _done = const {};
  Map<String, ScheduleChange> _changes = const {};
  String? _pinned;
  bool _loading = true;

  ScheduleRepository get _repo => context.read<AppServices>().scheduleRepo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.activitiesForDate(_date);
    final done = await _repo.completions(_date);
    final changes = await _repo.changes(_date);
    final pinned = await _repo.pinnedCurrent(_date);
    if (!mounted) return;
    setState(() {
      _items = items;
      _done = done;
      _changes = {for (final c in changes) c.activityId: c};
      _pinned = pinned;
      _loading = false;
    });
    // Đồng bộ màn hình của trẻ.
    context.read<ScheduleController>().load();
  }

  void _shift(int days) {
    setState(() => _date = LocalDate.addDays(_date, days));
    _load();
  }

  Future<void> _addOneOff() async {
    final a = await editActivity(
      context,
      Activity(
        id: _repo.newId(),
        localDate: _date,
        title: '',
        position: _items.isEmpty ? 0 : _items.last.position + 1,
      ),
      isNew: true,
    );
    if (a != null) {
      await _repo.saveActivity(a);
      await _load();
    }
  }

  Future<void> _action(Activity a, String action) async {
    switch (action) {
      case 'pin':
        await _repo.setPinnedCurrent(_date, a.id);
        break;
      case 'unpin':
        await _repo.setPinnedCurrent(_date, null);
        break;
      case 'done':
        await _repo.setStatus(a.id, _date, CompletionStatus.done);
        break;
      case 'clear':
        await _repo.clearStatus(a.id, _date);
        break;
      case 'change':
        await _reportChange(a);
        break;
      case 'unchange':
        final c = _changes[a.id];
        if (c != null) await _repo.deleteChange(c);
        break;
      case 'edit':
        final edited = await editActivity(context, a);
        if (edited != null) await _repo.saveActivity(edited);
        break;
      case 'delete':
        final ok = await confirmAction(
          context,
          title: 'Xóa hoạt động một lần?',
          message:
              'Xóa "${a.title}" khỏi ngày ${LocalDate.friendly(_date)}. Trạng thái đã ghi của hoạt động này cũng bị xóa.',
          confirmLabel: 'Xóa',
          destructive: true,
        );
        if (ok) await _repo.deleteActivity(a.id);
        break;
    }
    await _load();
  }

  Future<void> _reportChange(Activity a) async {
    final result = await Navigator.of(context).push<_ChangeResult>(
      caregiverRoute(_ChangeForm(activity: a, date: _date)),
    );
    if (result == null) return; // hủy trước khi lưu → giữ nguyên lịch
    await _repo.saveChange(result.change, replacement: result.replacement);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addOneOff,
        icon: const Icon(Icons.add),
        label: const Text('Hoạt động một lần'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.s),
            child: Row(
              children: [
                IconButton(
                    tooltip: 'Ngày trước',
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Text(LocalDate.friendly(_date),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                    tooltip: 'Ngày sau',
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right)),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const EmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'Ngày này chưa có hoạt động.',
                        hint:
                            'Thêm hoạt động một lần, hoặc tạo mẫu lịch áp dụng cho thứ này.',
                      )
                    : ListView(
                        padding: const EdgeInsets.only(bottom: 96),
                        children: [
                          for (final a in _items) _dayTile(a),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _dayTile(Activity a) {
    final st = _done[a.id]?.status;
    final change = _changes[a.id];
    final chips = <String>[
      if (_pinned == a.id) 'Được chỉ định hiện tại',
      if (st == CompletionStatus.done) 'Hoàn tất',
      if (st == CompletionStatus.later) 'Để sau',
      if (st == CompletionStatus.skipped) 'Bỏ qua',
      if (change != null)
        '${change.type.label}${change.message.isEmpty ? '' : ': ${change.message}'}',
      if (a.isOneOff) 'Một lần',
    ];
    return ListTile(
      leading: Pictogram(iconKey: a.iconKey, imageRef: a.imageRef, size: 44),
      title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text([
        if (a.optionalTime != null) a.optionalTime!,
        ...chips,
      ].join(' · ')),
      trailing: PopupMenuButton<String>(
        onSelected: (v) => _action(a, v),
        itemBuilder: (_) => [
          if (_pinned == a.id)
            const PopupMenuItem(value: 'unpin', child: Text('Bỏ chỉ định hiện tại'))
          else
            const PopupMenuItem(value: 'pin', child: Text('Chỉ định là hiện tại')),
          if (st == null)
            const PopupMenuItem(value: 'done', child: Text('Đánh dấu hoàn tất'))
          else
            const PopupMenuItem(value: 'clear', child: Text('Bỏ trạng thái')),
          if (change == null)
            const PopupMenuItem(
                value: 'change', child: Text('Báo thay đổi hôm nay…'))
          else
            const PopupMenuItem(value: 'unchange', child: Text('Hủy thay đổi')),
          if (a.isOneOff) ...[
            const PopupMenuItem(value: 'edit', child: Text('Sửa')),
            const PopupMenuItem(value: 'delete', child: Text('Xóa')),
          ],
        ],
      ),
    );
  }
}

class _ChangeResult {
  _ChangeResult(this.change, this.replacement);
  final ScheduleChange change;
  final Activity? replacement;
}

/// UC-CH-03: chọn loại thay đổi; "thay bằng" chọn nội dung mới; "chưa xác
/// định" ghi nhận trạng thái thay vì tự tạo hoạt động giả định.
class _ChangeForm extends StatefulWidget {
  const _ChangeForm({required this.activity, required this.date});
  final Activity activity;
  final String date;

  @override
  State<_ChangeForm> createState() => _ChangeFormState();
}

class _ChangeFormState extends State<_ChangeForm> {
  ChangeType _type = ChangeType.changed;
  final _message = TextEditingController();
  Activity? _replacement;
  String? _storyId;
  String? _cardId;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickReplacement() async {
    final repo = context.read<AppServices>().scheduleRepo;
    final a = await editActivity(
      context,
      _replacement ??
          Activity(
            id: repo.newId(),
            localDate: widget.date,
            title: '',
            position: widget.activity.position,
          ),
      isNew: _replacement == null,
    );
    if (a != null) setState(() => _replacement = a);
  }

  void _save() {
    if (_type == ChangeType.replaced && _replacement == null) {
      showInfo(context, 'Hãy chọn hoạt động thay thế.');
      return;
    }
    final repo = context.read<AppServices>().scheduleRepo;
    Navigator.pop(
      context,
      _ChangeResult(
        ScheduleChange(
          id: repo.newId(),
          activityId: widget.activity.id,
          localDate: widget.date,
          type: _type,
          replacementActivityId:
              _type == ChangeType.replaced ? _replacement!.id : null,
          message: _message.text.trim(),
          linkedStoryId: _storyId,
          linkedCardId: _cardId,
          createdAt: LocalDate.isoNow(),
        ),
        _type == ChangeType.replaced ? _replacement : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stories = context.watch<StoryController>().approved;
    final cards = context.watch<CardController>().visible;
    return Scaffold(
      appBar: AppBar(title: Text('Thay đổi: ${widget.activity.title}')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.m),
        children: [
          Text('Ngày: ${LocalDate.friendly(widget.date)}'),
          const SizedBox(height: Gap.m),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in ChangeType.values)
                ChoiceChip(
                  label: Text(t.label),
                  selected: _type == t,
                  onSelected: (_) => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: Gap.m),
          if (_type == ChangeType.replaced)
            ListTile(
              tileColor: Colors.white,
              leading: _replacement == null
                  ? const Icon(Icons.add_circle_outline)
                  : Pictogram(
                      iconKey: _replacement!.iconKey,
                      imageRef: _replacement!.imageRef,
                      size: 40),
              title: Text(_replacement?.title ?? 'Chọn hoạt động thay thế'),
              onTap: _pickReplacement,
            ),
          TextField(
            controller: _message,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Lời nhắn ngắn cho trẻ (tùy chọn)',
              hintText: 'Ví dụ: Hôm nay mưa, mình chơi trong nhà.',
            ),
          ),
          const SizedBox(height: Gap.s),
          DropdownButtonFormField<String?>(
            value: _storyId,
            decoration:
                const InputDecoration(labelText: 'Gắn câu chuyện đã duyệt'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Không gắn')),
              for (final s in stories)
                DropdownMenuItem(value: s.id, child: Text(s.title)),
            ],
            onChanged: (v) => setState(() => _storyId = v),
          ),
          const SizedBox(height: Gap.s),
          DropdownButtonFormField<String?>(
            value: _cardId,
            decoration: const InputDecoration(labelText: 'Gắn thẻ hỗ trợ'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Không gắn')),
              for (final c in cards)
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (v) => setState(() => _cardId = v),
          ),
          const SizedBox(height: Gap.m),
          const InfoNote(
              'Thay đổi chỉ áp dụng cho ngày này; mẫu lịch, các hoạt động khác '
              'và trạng thái hoàn tất đã ghi được giữ nguyên. Ứng dụng không '
              'tự phát âm thanh hay hoạt ảnh để báo thay đổi.'),
          const SizedBox(height: Gap.m),
          ElevatedButton(onPressed: _save, child: const Text('Lưu thay đổi')),
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy')),
        ],
      ),
    );
  }
}

// ===========================================================================
// Mẫu lịch lặp lại theo thứ
// ===========================================================================

class _TemplatesTab extends StatefulWidget {
  const _TemplatesTab();
  @override
  State<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends State<_TemplatesTab> {
  late Future<List<RoutineTemplate>> _future;
  ScheduleRepository get _repo => context.read<AppServices>().scheduleRepo;

  @override
  void initState() {
    super.initState();
    _future = _repo.templates();
  }

  void _reload() {
    setState(() => _future = _repo.templates());
    context.read<ScheduleController>().load();
  }

  Future<void> _create() async {
    final t = await _repo.createTemplate('Mẫu lịch mới', const [1, 2, 3, 4, 5]);
    if (!mounted) return;
    await Navigator.of(context)
        .push(caregiverRoute(_TemplateEditor(template: t)));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Mẫu lịch'),
      ),
      body: FutureBuilder<List<RoutineTemplate>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat_rounded,
              title: 'Chưa có mẫu lịch.',
              hint: 'Mẫu lịch giúp lặp lại hoạt động theo các ngày trong tuần.',
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              for (final t in list)
                ListTile(
                  title: Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text([
                    t.weekdays.map(LocalDate.weekdayShort).join(', '),
                    if (t.isSample) 'Dữ liệu minh họa',
                  ].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context)
                        .push(caregiverRoute(_TemplateEditor(template: t)));
                    _reload();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TemplateEditor extends StatefulWidget {
  const _TemplateEditor({required this.template});
  final RoutineTemplate template;

  @override
  State<_TemplateEditor> createState() => _TemplateEditorState();
}

class _TemplateEditorState extends State<_TemplateEditor> {
  late RoutineTemplate _t = widget.template;
  late final _title = TextEditingController(text: _t.title);
  List<Activity> _items = [];
  ScheduleRepository get _repo => context.read<AppServices>().scheduleRepo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await _repo.activitiesForTemplate(_t.id);
    if (mounted) setState(() => _items = items);
  }

  Future<void> _saveMeta() async {
    _t = await _repo.saveTemplate(_t.copyWith(
        title: _title.text.trim().isEmpty ? 'Mẫu lịch' : _title.text.trim()));
  }

  Future<void> _add() async {
    final a = await editActivity(
      context,
      Activity(
        id: _repo.newId(),
        templateId: _t.id,
        title: '',
        position: _items.length,
      ),
      isNew: true,
    );
    if (a != null) {
      await _repo.saveActivity(a);
      await _load();
    }
  }

  Future<void> _delete() async {
    final ok = await confirmAction(
      context,
      title: 'Xóa mẫu lịch?',
      message:
          'Xóa "${_t.title}" cùng ${_items.length} hoạt động trong mẫu và trạng thái đã ghi của chúng. Không thể hoàn tác.',
      confirmLabel: 'Xóa',
      destructive: true,
    );
    if (!ok) return;
    await _repo.deleteTemplate(_t.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _saveMeta();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mẫu lịch'),
          actions: [
            IconButton(
                tooltip: 'Xóa mẫu',
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          icon: const Icon(Icons.add),
          label: const Text('Hoạt động'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Gap.m),
              child: TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Tên mẫu'),
                onSubmitted: (_) => _saveMeta(),
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  FilterChip(
                    label: Text(LocalDate.weekdayShort(d)),
                    selected: _t.weekdays.contains(d),
                    onSelected: (v) async {
                      final days = [..._t.weekdays];
                      v ? days.add(d) : days.remove(d);
                      days.sort();
                      setState(() => _t = _t.copyWith(weekdays: days));
                      await _saveMeta();
                    },
                  ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.all(Gap.s),
              child: Text('Giữ và kéo để sắp xếp thứ tự.',
                  style: TextStyle(color: AppColors.muted)),
            ),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.only(bottom: 96),
                onReorder: (oldI, newI) async {
                  if (newI > oldI) newI -= 1;
                  final list = [..._items];
                  final moved = list.removeAt(oldI);
                  list.insert(newI, moved);
                  setState(() => _items = list);
                  await _repo.reorder(list.map((e) => e.id).toList());
                  await _load();
                },
                children: [
                  for (final a in _items)
                    ListTile(
                      key: ValueKey(a.id),
                      leading: Pictogram(
                          iconKey: a.iconKey, imageRef: a.imageRef, size: 44),
                      title: Text(a.title),
                      subtitle: Text([
                        if (a.optionalTime != null) a.optionalTime!,
                        if (a.subtitle.isNotEmpty) a.subtitle,
                      ].join(' · ')),
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'edit') {
                            final e = await editActivity(context, a);
                            if (e != null) await _repo.saveActivity(e);
                          } else if (v == 'dup') {
                            await _repo.duplicateActivity(a);
                          } else if (v == 'delete') {
                            final ok = await confirmAction(
                              context,
                              title: 'Xóa hoạt động?',
                              message:
                                  'Xóa "${a.title}" khỏi mẫu lịch. Trạng thái đã ghi của hoạt động này cũng bị xóa.',
                              confirmLabel: 'Xóa',
                              destructive: true,
                            );
                            if (ok) {
                              await _repo.deleteActivity(a.id);
                              if (!mounted) return;
                              await context
                                  .read<AppServices>()
                                  .photos
                                  .delete(a.imageRef);
                            }
                          }
                          await _load();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Sửa')),
                          PopupMenuItem(value: 'dup', child: Text('Nhân bản')),
                          PopupMenuItem(value: 'delete', child: Text('Xóa')),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Biểu mẫu hoạt động (UI-02) – kiểm tra dữ liệu không hợp lệ
// ===========================================================================

Future<Activity?> editActivity(BuildContext context, Activity a,
    {bool isNew = false}) {
  return Navigator.of(context).push<Activity>(
    caregiverRoute(_ActivityForm(activity: a, isNew: isNew)),
  );
}

class _ActivityForm extends StatefulWidget {
  const _ActivityForm({required this.activity, required this.isNew});
  final Activity activity;
  final bool isNew;

  @override
  State<_ActivityForm> createState() => _ActivityFormState();
}

class _ActivityFormState extends State<_ActivityForm> {
  final _form = GlobalKey<FormState>();
  late Activity _a = widget.activity;
  late final _title = TextEditingController(text: _a.title);
  late final _subtitle = TextEditingController(text: _a.subtitle);
  late final _note = TextEditingController(text: _a.note);

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _photo(bool camera) async {
    try {
      final path =
          await context.read<AppServices>().photos.pick(camera: camera);
      if (path != null) setState(() => _a = _a.copyWith(imageRef: path));
    } on PhotoException catch (e) {
      showInfo(context, e.message);
    } catch (_) {
      showInfo(context, 'Không mở được ảnh. Hãy kiểm tra quyền truy cập ảnh.');
    }
  }

  Future<void> _time() async {
    final m = LocalDate.minutesOf(_a.optionalTime);
    final t = await showTimePicker(
      context: context,
      initialTime: m == null
          ? const TimeOfDay(hour: 8, minute: 0)
          : TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    if (t != null) {
      setState(() => _a = _a.copyWith(
          optionalTime:
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'));
    }
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(
      context,
      _a.copyWith(
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        note: _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isNew ? 'Thêm hoạt động' : 'Sửa hoạt động')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(Gap.m),
          children: [
            Center(
              child: Pictogram(
                iconKey: _a.iconKey,
                imageRef: _a.imageRef,
                size: 120,
                background: AppColors.cream,
              ),
            ),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final k = await pickIcon(context,
                        keys: IconCatalog.activityKeys, selected: _a.iconKey);
                    if (k != null) setState(() => _a = _a.copyWith(iconKey: k));
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
                if (_a.imageRef != null)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _a = _a.copyWith(clearImage: true)),
                    icon: const Icon(Icons.hide_image_outlined),
                    label: const Text('Bỏ ảnh'),
                  ),
              ],
            ),
            const SizedBox(height: Gap.m),
            TextFormField(
              controller: _title,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Tên ngắn *'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Cần có tên hoạt động.'
                  : null,
            ),
            TextFormField(
              controller: _subtitle,
              maxLength: 60,
              decoration: const InputDecoration(
                  labelText: 'Mô tả ngắn (tùy chọn)',
                  hintText: 'Ví dụ: Sau khi ăn sáng'),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: Text(_a.optionalTime ?? 'Không đặt giờ'),
              subtitle: const Text('Thời gian là tùy chọn.'),
              onTap: _time,
              trailing: _a.optionalTime == null
                  ? null
                  : IconButton(
                      tooltip: 'Bỏ giờ',
                      icon: const Icon(Icons.clear),
                      onPressed: () =>
                          setState(() => _a = _a.copyWith(clearTime: true)),
                    ),
            ),
            TextFormField(
              controller: _note,
              maxLength: 200,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Ghi chú cho người lớn (trẻ không thấy)'),
            ),
            const SizedBox(height: Gap.m),
            ElevatedButton(onPressed: _save, child: const Text('Lưu')),
          ],
        ),
      ),
    );
  }
}
