import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/story_controller.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'caregiver_guard.dart';
import 'story_create_screen.dart';
import 'story_editor_screen.dart';

/// Danh sách câu chuyện (mọi trạng thái) – chỉ trong khu vực người chăm sóc.
class StoryListScreen extends StatelessWidget {
  const StoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StoryController>();
    final stories = ctrl.all;
    return Scaffold(
      appBar: AppBar(title: const Text('Câu chuyện xã hội')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context)
            .push(caregiverRoute(const StoryCreateScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Câu chuyện mới'),
      ),
      body: stories.isEmpty
          ? const EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Chưa có câu chuyện.',
              hint:
                  'Tạo câu chuyện ngắn để giới thiệu trước một sự kiện như đi khám, cắt tóc.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 96),
              children: [
                const InfoNote(
                    'Trẻ chỉ thấy câu chuyện "Đã duyệt". Bản nháp và câu chuyện lưu trữ luôn ẩn với trẻ.'),
                for (final s in stories)
                  ListTile(
                    leading: Pictogram(
                      iconKey:
                          s.steps.isNotEmpty ? s.steps.first.iconKey : 'book',
                      imageRef:
                          s.steps.isNotEmpty ? s.steps.first.imageRef : null,
                      size: 48,
                      background: AppColors.lightBlue,
                    ),
                    title: Text(s.title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(spacing: 6, runSpacing: 4, children: [
                        StatusPill(status: s.status),
                        Pill('Nguồn: ${s.source.label}',
                            color: AppColors.lightBlue),
                        if (s.isSample)
                          const Pill('Minh họa', color: AppColors.cream),
                      ]),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                        caregiverRoute(StoryEditorScreen(storyId: s.id))),
                  ),
              ],
            ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final StoryStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case StoryStatus.approved:
        return Pill(status.label,
            color: AppColors.accentBg, icon: Icons.verified_rounded);
      case StoryStatus.draft:
        return Pill(status.label,
            color: AppColors.cream, icon: Icons.edit_note_rounded);
      case StoryStatus.archived:
        return Pill(status.label,
            color: const Color(0xFFEDEDED), icon: Icons.archive_outlined);
    }
  }
}
