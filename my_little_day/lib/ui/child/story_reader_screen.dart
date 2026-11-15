import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/tts_service.dart';
import '../../state/card_controller.dart';
import '../../state/settings_controller.dart';
import '../../state/story_controller.dart';
import '../widgets/comm_card_tile.dart';
import '../widgets/pictogram.dart';
import 'quick_help_sheet.dart';

/// Đọc câu chuyện theo từng bước (Hình 8, UC-CH-05).
///
/// - Vuốt ngang để lật trang như đọc sách; nút lớn vẫn có cho trẻ cần.
/// - Mỗi bước: một hình chính (ảnh thật nếu có) + một câu ngắn, chữ lớn.
/// - Thẻ hỗ trợ liên kết mở đúng thẻ M2; quay lại đúng bước đang đọc.
/// - Nếu câu chuyện bị thu hồi trong lúc xem → đóng, thông báo ngắn.
/// - [preview]: người chăm sóc xem trước bản nháp (không kiểm tra duyệt).
class StoryReaderScreen extends StatefulWidget {
  const StoryReaderScreen({super.key, this.storyId, this.preview});

  final String? storyId;
  final SocialStory? preview;

  @override
  State<StoryReaderScreen> createState() => _StoryReaderScreenState();
}

class _StoryReaderScreenState extends State<StoryReaderScreen> {
  final _page = PageController();
  int _index = 0;
  bool _closing = false;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _revoked() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(
          content: Text('Câu chuyện này tạm thời không còn trong thư viện.')));
    });
  }

  void _go(int i, bool motion) {
    _page.animateToPage(
      i,
      duration: motion
          ? const Duration(milliseconds: 300)
          : const Duration(milliseconds: 1),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    SocialStory? story = widget.preview;
    if (story == null) {
      story = context.watch<StoryController>().byId(widget.storyId!);
      if (story == null || !story.visibleToChild) {
        _revoked();
        return const Scaffold(body: SizedBox.shrink());
      }
    }
    final s = story;
    final steps = s.steps;
    final total = steps.length;
    final cards = context.watch<CardController>();
    final linked = s.linkedCardIds
        .map(cards.byId)
        .whereType<CommunicationCard>()
        .where((c) => !c.hidden)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    iconSize: 32,
                    tooltip: S.back,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  Expanded(
                    child: Text(
                      widget.preview != null
                          ? 'Xem trước – ${s.title}'
                          : 'Câu chuyện – ${s.title}',
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              if (total > 0) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Gap.s),
                  child: Text('Bước ${_index + 1} / $total',
                      style: const TextStyle(color: AppColors.muted)),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: (_index + 1) / total,
                    minHeight: 10,
                    backgroundColor: AppColors.accentBg,
                    color: AppColors.primary,
                  ),
                ),
              ],
              const SizedBox(height: Gap.m),
              Expanded(
                child: total == 0
                    ? const Center(child: Text('Câu chuyện chưa có bước nào.'))
                    : PageView.builder(
                        controller: _page,
                        itemCount: total,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (_, i) => _StepPage(step: steps[i]),
                      ),
              ),
              if (linked.isNotEmpty) ...[
                const SizedBox(height: Gap.s),
                SizedBox(
                  height: 76,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: linked.length,
                    separatorBuilder: (_, __) => const SizedBox(width: Gap.s),
                    itemBuilder: (_, i) => SizedBox(
                      width: 200,
                      child: _LinkedCardButton(
                        card: linked[i],
                        enabled: widget.preview == null,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: Gap.m),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 64)),
                      onPressed: _index > 0
                          ? () => _go(_index - 1, settings.animationsOn)
                          : null,
                      icon: const Icon(Icons.chevron_left_rounded, size: 32),
                      label: const Text(S.back),
                    ),
                  ),
                  const SizedBox(width: Gap.m),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          minimumSize: const Size(48, 64)),
                      onPressed: total == 0
                          ? null
                          : (_index < total - 1
                              ? () => _go(_index + 1, settings.animationsOn)
                              : () => Navigator.pop(context)),
                      icon: Icon(
                          _index < total - 1
                              ? Icons.chevron_right_rounded
                              : Icons.check_rounded,
                          size: 32),
                      label: Text(
                          _index < total - 1 ? S.nextStep : S.finish),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});
  final StoryStep step;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.lightBlue,
                borderRadius: BorderRadius.circular(18),
              ),
              child: LayoutBuilder(
                builder: (_, box) => Center(
                  child: Pictogram(
                    iconKey: step.iconKey,
                    imageRef: step.imageRef,
                    size: (box.biggest.shortestSide * 0.85).clamp(80, 320),
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.m),
          Text(
            step.text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          if (settings.canSpeak)
            IconButton(
              iconSize: 32,
              tooltip: 'Nghe',
              onPressed: () => context
                  .read<SpeechService>()
                  .speak(step.text, rate: settings.ttsRate),
              icon: const Icon(Icons.volume_up_rounded),
            ),
        ],
      ),
    );
  }
}

class _LinkedCardButton extends StatelessWidget {
  const _LinkedCardButton({required this.card, required this.enabled});
  final CommunicationCard card;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(card.category);
    return Material(
      color: color.withOpacity(0.12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color, width: 2.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Mở thẻ không làm đổi trạng thái duyệt; pop về đúng bước hiện tại.
        onTap: enabled ? () => openCard(context, card) : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.m),
          child: Row(
            children: [
              Pictogram(
                  iconKey: card.iconKey,
                  imageRef: card.imageRef,
                  size: 40,
                  color: AppColors.text),
              const SizedBox(width: Gap.s),
              Expanded(
                child: Text(card.spoken,
                    maxLines: 2,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
