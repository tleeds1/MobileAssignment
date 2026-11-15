import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories/card_repository.dart';
import '../services/tts_service.dart';
import 'settings_controller.dart';

/// Thư viện thẻ + thanh ghép câu (góp ý: hỗ trợ "CON MUỐN + UỐNG + NƯỚC CAM").
class CardController extends ChangeNotifier {
  CardController(this.repo, this._settings, this._speech);

  final CardRepository repo;
  final SettingsController _settings;
  final SpeechService _speech;

  static const maxSentence = 8;

  List<CommunicationCard> _all = const [];
  final List<CommunicationCard> _sentence = [];
  bool _loading = false;

  List<CommunicationCard> get all => _all;
  List<CommunicationCard> get visible =>
      _all.where((c) => !c.hidden).toList();
  List<CommunicationCard> get favorites =>
      visible.where((c) => c.favorite).toList();
  List<CommunicationCard> get sentence => List.unmodifiable(_sentence);
  bool get loading => _loading;

  String get sentenceText {
    if (_sentence.isEmpty) return '';
    // Ghép bằng nhãn/nội dung ngắn; chữ cái đầu viết hoa.
    final words = _sentence.map((c) => c.spoken.trim()).join(' ');
    return words[0].toUpperCase() + words.substring(1);
  }

  CommunicationCard? byId(String id) {
    for (final c in _all) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _all = await repo.all();
    _sentence.removeWhere((s) => byId(s.id) == null);
    _loading = false;
    notifyListeners();
  }

  /// Trẻ chạm một thẻ: (1) ghi tần suất nếu được bật, (2) đọc nếu được bật.
  /// Việc chạm thẻ KHÔNG mặc nhiên tạo bản ghi (UC-CH-01).
  Future<void> use(CommunicationCard card, {bool addToSentence = false}) async {
    final s = _settings.value;
    if (addToSentence && _sentence.length < maxSentence) {
      _sentence.add(card);
      notifyListeners();
    }
    if (s.cardUsageLogEnabled) {
      await repo.logUsage(card.id);
    }
    if (s.canSpeak) {
      await _speech.speak(card.spoken, rate: s.ttsRate);
    }
  }

  Future<void> speakSentence() async {
    final s = _settings.value;
    if (s.canSpeak && _sentence.isNotEmpty) {
      await _speech.speak(sentenceText, rate: s.ttsRate);
    }
  }

  void removeLast() {
    if (_sentence.isNotEmpty) {
      _sentence.removeLast();
      notifyListeners();
    }
  }

  void removeAt(int i) {
    if (i >= 0 && i < _sentence.length) {
      _sentence.removeAt(i);
      notifyListeners();
    }
  }

  void clearSentence() {
    _sentence.clear();
    _speech.stop();
    notifyListeners();
  }
}
