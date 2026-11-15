import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import 'pictogram.dart';

Color categoryColor(CardCategory c) {
  switch (c) {
    case CardCategory.person:
      return FitzgeraldColors.person;
    case CardCategory.action:
      return FitzgeraldColors.action;
    case CardCategory.thing:
      return FitzgeraldColors.thing;
    case CardCategory.describe:
      return FitzgeraldColors.describe;
    case CardCategory.social:
      return FitzgeraldColors.social;
    case CardCategory.help:
      return FitzgeraldColors.help;
    case CardCategory.urgent:
      return FitzgeraldColors.urgent;
  }
}

/// Dấu hiệu nhóm bằng hình dạng – để màu không phải tín hiệu duy nhất (NFR-04).
IconData categoryMarker(CardCategory c) {
  switch (c) {
    case CardCategory.person:
      return Icons.circle;
    case CardCategory.action:
      return Icons.play_arrow_rounded;
    case CardCategory.thing:
      return Icons.square_rounded;
    case CardCategory.describe:
      return Icons.change_history_rounded;
    case CardCategory.social:
      return Icons.favorite_rounded;
    case CardCategory.help:
      return Icons.star_rounded;
    case CardCategory.urgent:
      return Icons.priority_high_rounded;
  }
}

/// Thẻ giao tiếp: viền dày theo mã màu Fitzgerald + bóng đổ tạo chiều sâu.
/// Thẻ khẩn cấp có nền ấm nhạt để nhận ra ngay cả khi trẻ đang hoảng.
class CommCardTile extends StatefulWidget {
  const CommCardTile({
    super.key,
    required this.card,
    required this.onTap,
    this.showLabel = true,
    this.compact = false,
  });

  final CommunicationCard card;
  final VoidCallback onTap;
  final bool showLabel;
  final bool compact;

  @override
  State<CommCardTile> createState() => _CommCardTileState();
}

class _CommCardTileState extends State<CommCardTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.card;
    final color = categoryColor(c.category);
    final urgent =
        c.category == CardCategory.urgent || c.category == CardCategory.help;
    return Semantics(
      button: true,
      label: 'Thẻ: ${c.spoken}',
      hint: c.category.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
          decoration: BoxDecoration(
            color: urgent ? color.withOpacity(0.10) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 4),
            boxShadow: _pressed
                ? const []
                : [
                    BoxShadow(
                      color: color.withOpacity(0.55),
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Stack(
            children: [
              Positioned(
                top: 6,
                left: 8,
                child: Icon(categoryMarker(c.category),
                    size: 16, color: color),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: FittedBox(
                          child: Pictogram(
                            iconKey: c.iconKey,
                            imageRef: c.imageRef,
                            size: widget.compact ? 40 : 72,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      if (widget.showLabel) ...[
                        const SizedBox(height: 6),
                        Text(
                          c.label,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: widget.compact ? 14 : 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
