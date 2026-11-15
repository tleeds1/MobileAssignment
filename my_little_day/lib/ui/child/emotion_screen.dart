import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/strings.dart';
import '../../core/tap_guard.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../state/card_controller.dart';
import '../../state/emotion_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import '../widgets/pictogram.dart';
import 'breathing_screen.dart';
import 'quick_help_sheet.dart';

/// M3 – Check-in cảm xúc (UC-CH-04, Hình 7).
///
/// - Không đúng/sai, không điểm số, không chuỗi ngày, không nhắc nhở.
/// - Thoát / "Con chưa biết" / "Bỏ qua" KHÔNG tạo bản ghi (TC-08, TC-27).
/// - Có nhóm "Cơ thể" (đau đầu, nóng người, muốn hét, bụng cồn cào) vì trẻ
///   thường nhận diện cảm giác cơ thể tốt hơn khái niệm cảm xúc trừu tượng.
/// - Sau lựa chọn được đánh dấu, gợi ý nhẹ nhàng các cách hỗ trợ.
class EmotionScreen extends StatefulWidget {
  const EmotionScreen({
    super.key,
    required this.onOpenCaregiver,
    required this.onOpenTalk,
  });

  final VoidCallback onOpenCaregiver;
  final VoidCallback onOpenTalk;

  @override
  State<EmotionScreen> createState() => _EmotionScreenState();
}

class _EmotionScreenState extends State<EmotionScreen> {
  EmotionKind _kind = EmotionKind.feeling;
  EmotionOption? _selected;
  String? _ack;
  final _guard = TapGuard();

  void _reset([String? ack]) {
    setState(() {
      _selected = null;
      _ack = ack;
    });
    if (ack != null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _ack == ack) setState(() => _ack = null);
      });
    }
  }

  Future<void> _confirm() async {
    final option = _selected;
    if (option == null || !_guard.allow('confirm')) return;
    await context.read<EmotionController>().confirm(option);
    if (!mounted) return;
    final settings = context.read<SettingsController>().value;
    _reset('Cảm ơn con đã cho biết.');
    if (option.suggestSupport && settings.supportSuggestionEnabled) {
      await _showSupport(option);
    }
  }

  Future<void> _showSupport(EmotionOption option) async {
    final cards = context.read<CardController>().visible;
    CommunicationCard? find(String icon) {
      for (final c in cards) {
        if (c.iconKey == icon) return c;
      }
      return null;
    }

    final rest = find('rest');
    final help = find('help');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Con có muốn thử một điều không?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: Gap.m),
              if (rest != null)
                _SupportOption(
                  icon: 'rest',
                  label: rest.label,
                  onTap: () {
                    Navigator.pop(ctx);
                    openCard(context, rest);
                  },
                ),
              if (help != null)
                _SupportOption(
                  icon: 'help',
                  label: help.label,
                  onTap: () {
                    Navigator.pop(ctx);
                    openCard(context, help);
                  },
                ),
              _SupportOption(
                icon: 'calm',
                label: 'Thở chậm',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const BreathingScreen()));
                },
              ),
              _SupportOption(
                icon: 'want',
                label: 'Dùng thẻ để nói',
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onOpenTalk();
                },
              ),
              const SizedBox(height: Gap.s),
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Không, cảm ơn'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<EmotionController>().options;
    final hasBody = all.any((o) => o.kind == EmotionKind.body);
    final options = all.where((o) => o.kind == _kind).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 72),
          child: ChildHeader(
            title: S.feelTitle,
            subtitle: S.feelSubtitle,
            onSecret: widget.onOpenCaregiver,
          ),
        ),
        if (hasBody)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Gap.m),
            child: Row(
              children: [
                _KindChip(
                  label: S.feelTab,
                  icon: Icons.sentiment_satisfied_rounded,
                  selected: _kind == EmotionKind.feeling,
                  onTap: () => setState(() {
                    _kind = EmotionKind.feeling;
                    _selected = null;
                  }),
                ),
                const SizedBox(width: Gap.s),
                _KindChip(
                  label: S.bodyTab,
                  icon: Icons.accessibility_new_rounded,
                  selected: _kind == EmotionKind.body,
                  onTap: () => setState(() {
                    _kind = EmotionKind.body;
                    _selected = null;
                  }),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Gap.m),
            children: [
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: [
                  for (final o in options)
                    _EmotionTile(
                      option: o,
                      selected: _selected?.id == o.id,
                      onTap: () => setState(() {
                        _selected = o;
                        _ack = null;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: Gap.m),
              if (_selected != null)
                _ConfirmBar(
                  label: _selected!.label,
                  onYes: _confirm,
                  onChange: () => _reset(),
                )
              else ...[
                OutlinedButton(
                  onPressed: () => _reset('Được rồi.'),
                  child: const Text(S.dontKnow),
                ),
                const SizedBox(height: Gap.s),
                OutlinedButton(
                  onPressed: () => _reset('Được rồi.'),
                  child: const Text(S.skip),
                ),
              ],
              if (_ack != null) ...[
                const SizedBox(height: Gap.m),
                Semantics(
                  liveRegion: true,
                  child: Text(_ack!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: Gap.m),
              Container(
                padding: const EdgeInsets.all(Gap.m),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Nếu cần giúp, con có thể chọn thẻ "Giúp con" hoặc "Nghỉ".',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KindChip extends StatelessWidget {
  const _KindChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? AppColors.accentBg : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
                color: selected ? AppColors.primary : AppColors.border,
                width: 2),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon),
                  const SizedBox(width: 6),
                  Text(label,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmotionTile extends StatelessWidget {
  const _EmotionTile(
      {required this.option, required this.selected, required this.onTap});
  final EmotionOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? AppColors.accentBg : Colors.white,
        elevation: selected ? 0 : 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 3 : 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Pictogram(
                      iconKey: option.iconKey,
                      imageRef: option.imageRef,
                      size: 76,
                      color: AppColors.text,
                      background: AppColors.cream,
                      radius: 40,
                    ),
                    const SizedBox(height: Gap.s),
                    Text(option.label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(Icons.check_circle_rounded,
                      color: AppColors.primary, size: 28),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmBar extends StatelessWidget {
  const _ConfirmBar(
      {required this.label, required this.onYes, required this.onChange});
  final String label;
  final VoidCallback onYes;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Gap.m),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Con chọn: $label',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: Gap.m),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                    onPressed: onChange, child: const Text(S.change)),
              ),
              const SizedBox(width: Gap.s),
              Expanded(
                child: ElevatedButton(
                    onPressed: onYes, child: const Text(S.yes)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupportOption extends StatelessWidget {
  const _SupportOption(
      {required this.icon, required this.label, required this.onTap});
  final String icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.s),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(Gap.m),
            child: Row(
              children: [
                Pictogram(iconKey: icon, size: 44, color: AppColors.text),
                const SizedBox(width: Gap.m),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
