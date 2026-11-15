import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/card_controller.dart';
import '../widgets/comm_card_tile.dart';
import 'card_display_screen.dart';

/// Biểu tượng góc nổi "Con cần giúp" (thay cho thanh chiếm diện tích lớn).
class QuickHelpButton extends StatelessWidget {
  const QuickHelpButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${S.help}: mở thẻ giao tiếp nhanh',
      excludeSemantics: true,
      child: Material(
        color: FitzgeraldColors.help.withOpacity(0.18),
        shape: const CircleBorder(
          side: BorderSide(color: FitzgeraldColors.help, width: 2.5),
        ),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => showQuickHelp(context),
          child: const SizedBox(
            width: 60,
            height: 60,
            child: Icon(Icons.back_hand_rounded,
                size: 32, color: AppColors.text),
          ),
        ),
      ),
    );
  }
}

/// Thẻ ưu tiên (nghỉ, giúp, dừng, không, đau) trong tối đa HAI thao tác từ
/// màn hình chính (FR-M2-09, TC-25).
Future<void> showQuickHelp(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final cards = ctx.watch<CardController>().favorites;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(S.help,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: Gap.m),
              if (cards.isEmpty)
                const Text('Chưa có thẻ ưu tiên.')
              else
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final c in cards.take(6))
                      CommCardTile(
                        card: c,
                        onTap: () {
                          Navigator.pop(ctx);
                          openCard(context, c);
                        },
                      ),
                  ],
                ),
            ],
          ),
        ),
      );
    },
  );
}

/// Mở thẻ toàn màn hình và (nếu được bật) đọc nội dung.
Future<void> openCard(BuildContext context, CommunicationCard card) {
  context.read<CardController>().use(card);
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => CardDisplayScreen(card: card)),
  );
}
