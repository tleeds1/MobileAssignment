import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/story_controller.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'story_reader_screen.dart';

/// Thư viện câu chuyện của trẻ (UI-05) – CHỈ câu chuyện đã duyệt (BR-04).
class StoriesScreen extends StatelessWidget {
  const StoriesScreen({super.key, required this.onOpenCaregiver});

  final VoidCallback onOpenCaregiver;

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<StoryController>();
    final stories = ctrl.approved;
    Widget body;
    if (ctrl.loading && stories.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (stories.isEmpty) {
      body = const EmptyState(
        icon: Icons.menu_book_outlined,
        title: S.storiesEmpty,
        hint: 'Người lớn có thể chuẩn bị câu chuyện trong Góc người chăm sóc.',
      );
    } else {
      body = ListView.separated(
        padding: const EdgeInsets.all(Gap.m),
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(height: Gap.m),
        itemBuilder: (_, i) => _StoryTile(story: stories[i]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 72),
          child: ChildHeader(
              title: S.storiesTitle, onSecret: onOpenCaregiver),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.story});
  final SocialStory story;

  @override
  Widget build(BuildContext context) {
    final first = story.steps.isNotEmpty ? story.steps.first : null;
    return Semantics(
      button: true,
      label: 'Câu chuyện: ${story.title}, ${story.steps.length} bước',
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        elevation: 2,
        shadowColor: AppColors.shadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => StoryReaderScreen(storyId: story.id))),
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Row(
              children: [
                Pictogram(
                  iconKey: first?.iconKey ?? 'book',
                  imageRef: first?.imageRef,
                  size: 80,
                  background: AppColors.lightBlue,
                ),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(story.title,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      Text('${story.steps.length} bước',
                          style: const TextStyle(color: AppColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, size: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
