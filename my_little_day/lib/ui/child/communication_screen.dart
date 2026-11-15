import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/tap_guard.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/card_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/comm_card_tile.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'card_display_screen.dart';
import 'quick_help_sheet.dart';

/// M2 – Giao tiếp bằng hình ảnh (UC-CH-01, Hình 6) + thanh ghép câu AAC.
///
/// - Thẻ giữ VỊ TRÍ CỐ ĐỊNH theo `position`; đổi 4/6/8 thẻ/màn hình chỉ chia lại
///   trang, không đảo thứ tự tương đối (trí nhớ cơ bắp).
/// - Thẻ khẩn cấp/trợ giúp mở toàn màn hình ngay; thẻ khác thêm vào thanh câu.
/// - Không có dải "Giọng đọc: Bật" trên giao diện trẻ (góp ý review).
class CommunicationScreen extends StatefulWidget {
  const CommunicationScreen({super.key, required this.onOpenCaregiver});

  final VoidCallback onOpenCaregiver;

  @override
  State<CommunicationScreen> createState() => _CommunicationScreenState();
}

class _CommunicationScreenState extends State<CommunicationScreen> {
  final _guard = TapGuard(interval: const Duration(milliseconds: 600));
  final _page = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _onCard(CommunicationCard card, AppSettings settings) {
    if (!_guard.allow(card.id)) return; // chống gõ lặp
    final immediate = card.category == CardCategory.urgent ||
        card.category == CardCategory.help ||
        !settings.sentenceStripEnabled;
    if (immediate) {
      openCard(context, card);
    } else {
      context.read<CardController>().use(card, addToSentence: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CardController>();
    final settings = context.watch<SettingsController>().value;
    // Dùng toàn bộ danh sách: thẻ "tạm ẩn" để lại ô trống thay vì làm các
    // thẻ phía sau dồn lên (giữ trí nhớ vị trí của trẻ).
    final cards = ctrl.all;
    final perPage = settings.cardsPerScreen;
    final pages = <List<CommunicationCard>>[];
    for (var i = 0; i < cards.length; i += perPage) {
      pages.add(cards.sublist(
          i, i + perPage > cards.length ? cards.length : i + perPage));
    }
    if (_pageIndex >= pages.length && pages.isNotEmpty) {
      _pageIndex = pages.length - 1;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChildHeader(
          title: S.talkTitle,
          subtitle: S.talkSubtitle,
          onSecret: widget.onOpenCaregiver,
        ),
        if (settings.sentenceStripEnabled) const _SentenceStrip(),
        Expanded(
          child: ctrl.loading && cards.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : ctrl.visible.isEmpty
                  ? const EmptyState(
                      icon: Icons.grid_view_rounded,
                      title: 'Chưa có thẻ nào.',
                      hint: 'Người lớn có thể thêm thẻ trong Góc người chăm sóc.',
                    )
                  : PageView.builder(
                      controller: _page,
                      itemCount: pages.length,
                      onPageChanged: (i) => setState(() => _pageIndex = i),
                      itemBuilder: (_, p) => _CardGrid(
                        cards: pages[p],
                        perPage: perPage,
                        showLabels: settings.showLabels,
                        onTap: (c) => _onCard(c, settings),
                      ),
                    ),
        ),
        if (pages.length > 1)
          _PageControls(
            index: _pageIndex,
            count: pages.length,
            onPage: (i) => _page.animateToPage(
              i,
              duration: settings.animationsOn
                  ? const Duration(milliseconds: 250)
                  : const Duration(milliseconds: 1),
              curve: Curves.easeOut,
            ),
          ),
      ],
    );
  }
}

class _CardGrid extends StatelessWidget {
  const _CardGrid({
    required this.cards,
    required this.perPage,
    required this.showLabels,
    required this.onTap,
  });

  final List<CommunicationCard> cards;
  final int perPage;
  final bool showLabels;
  final ValueChanged<CommunicationCard> onTap;

  @override
  Widget build(BuildContext context) {
    final rows = perPage ~/ 2;
    return LayoutBuilder(builder: (context, box) {
      const spacing = 12.0;
      final cellH = (box.maxHeight - Gap.m * 2 - spacing * (rows - 1)) / rows;
      final cellW = (box.maxWidth - Gap.m * 2 - spacing) / 2;
      final ratio = cellH > 0 ? cellW / cellH : 1.0;
      return GridView.builder(
        padding: const EdgeInsets.all(Gap.m),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: ratio.clamp(0.6, 2.2).toDouble(),
        ),
        // Luôn đủ số ô của trang để thẻ không "nhảy chỗ" khi trang cuối thiếu.
        itemCount: perPage,
        itemBuilder: (_, i) => i < cards.length && !cards[i].hidden
            ? CommCardTile(
                card: cards[i],
                showLabel: showLabels,
                compact: perPage == 8,
                onTap: () => onTap(cards[i]),
              )
            : const SizedBox.shrink(),
      );
    });
  }
}

class _PageControls extends StatelessWidget {
  const _PageControls(
      {required this.index, required this.count, required this.onPage});
  final int index;
  final int count;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.m, 0, Gap.m, Gap.s),
      child: Row(
        children: [
          IconButton(
            iconSize: 36,
            tooltip: 'Trang trước',
            onPressed: index > 0 ? () => onPage(index - 1) : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Text('Trang ${index + 1}/$count',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            iconSize: 36,
            tooltip: 'Trang sau',
            onPressed: index < count - 1 ? () => onPage(index + 1) : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// Thanh ghép câu: CON + MUỐN + UỐNG + NƯỚC CAM.
class _SentenceStrip extends StatelessWidget {
  const _SentenceStrip();

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<CardController>();
    final settings = context.watch<SettingsController>().value;
    final words = ctrl.sentence;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: Gap.m),
      padding: const EdgeInsets.all(Gap.s),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 76,
            child: words.isEmpty
                ? const Center(
                    child: Text(S.sentenceEmpty,
                        style: TextStyle(color: AppColors.muted)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: words.length,
                    separatorBuilder: (_, __) => const Icon(
                        Icons.add_rounded,
                        size: 18,
                        color: AppColors.muted),
                    itemBuilder: (_, i) => Semantics(
                      button: true,
                      label: 'Bỏ từ ${words[i].label}',
                      excludeSemantics: true,
                      child: InkWell(
                        onTap: () => ctrl.removeAt(i),
                        child: SizedBox(
                          width: 72,
                          child: Column(
                            children: [
                              Pictogram(
                                  iconKey: words[i].iconKey,
                                  imageRef: words[i].imageRef,
                                  size: 44,
                                  color: AppColors.text),
                              Text(words[i].label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          Row(
            children: [
              if (settings.canSpeak)
                Expanded(
                  child: _StripButton(
                    icon: Icons.volume_up_rounded,
                    label: S.speakSentence,
                    onTap: words.isEmpty ? null : ctrl.speakSentence,
                  ),
                ),
              Expanded(
                child: _StripButton(
                  icon: Icons.fullscreen_rounded,
                  label: S.showSentence,
                  onTap: words.isEmpty
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) =>
                              CardDisplayScreen(sentence: words.toList()))),
                ),
              ),
              _StripIcon(
                icon: Icons.backspace_outlined,
                tooltip: 'Xóa từ cuối',
                onTap: words.isEmpty ? null : ctrl.removeLast,
              ),
              _StripIcon(
                icon: Icons.clear_all_rounded,
                tooltip: 'Xóa cả câu',
                onTap: words.isEmpty ? null : ctrl.clearSentence,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StripButton extends StatelessWidget {
  const _StripButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _StripIcon extends StatelessWidget {
  const _StripIcon(
      {required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => IconButton(
        iconSize: 28,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        tooltip: tooltip,
        onPressed: onTap,
        icon: Icon(icon),
      );
}
