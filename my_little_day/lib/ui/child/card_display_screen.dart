import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../data/models.dart';
import '../../services/tts_service.dart';
import '../../state/settings_controller.dart';
import '../widgets/comm_card_tile.dart';
import '../widgets/pictogram.dart';

/// Hiển thị thẻ (hoặc câu đã ghép) thật to để trẻ đưa cho người lớn xem.
/// Không tự phát âm khi mở – âm thanh đã phát theo thao tác chạm trước đó.
class CardDisplayScreen extends StatelessWidget {
  const CardDisplayScreen({super.key, this.card, this.sentence});

  final CommunicationCard? card;
  final List<CommunicationCard>? sentence;

  String get _text {
    if (card != null) return card!.spoken;
    final words = sentence!.map((c) => c.spoken.trim()).join(' ');
    return words.isEmpty ? '' : words[0].toUpperCase() + words.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().value;
    final color = card != null ? categoryColor(card!.category) : AppColors.primary;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.m),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  iconSize: 36,
                  tooltip: 'Đóng',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(Gap.l),
                  decoration: BoxDecoration(
                    border: Border.all(color: color, width: 6),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (card != null)
                        Pictogram(
                          iconKey: card!.iconKey,
                          imageRef: card!.imageRef,
                          size: 200,
                          color: AppColors.text,
                        )
                      else
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final c in sentence!)
                              Pictogram(
                                iconKey: c.iconKey,
                                imageRef: c.imageRef,
                                size: 88,
                                color: AppColors.text,
                              ),
                          ],
                        ),
                      const SizedBox(height: Gap.l),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 36, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (settings.canSpeak) ...[
                const SizedBox(height: Gap.m),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context
                        .read<SpeechService>()
                        .speak(_text, rate: settings.ttsRate),
                    icon: const Icon(Icons.volume_up_rounded, size: 28),
                    label: const Text('Nghe lại'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
