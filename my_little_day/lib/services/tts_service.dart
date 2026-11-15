import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Bọc TTS của hệ điều hành (FR-M2-03, FR-M2-08, BR-10).
///
/// - Không bao giờ tự phát khi mở màn hình – chỉ gọi sau thao tác chủ động.
/// - Luôn `stop()` trước khi nói câu mới → không có hai luồng âm thanh chồng
///   nhau khi trẻ gõ liên thanh (góp ý review).
/// - Bỏ qua cùng một câu lặp lại trong [repeatWindow].
/// - Nếu máy không có giọng vi-VN, [available] = false; giao diện vẫn dùng
///   hình + chữ đầy đủ, không có trạng thái bế tắc (TC-07).
abstract class SpeechService extends ChangeNotifier {
  bool get available;
  bool get speaking;
  Future<void> init();
  Future<void> speak(String text, {double rate});
  Future<void> stop();
}

class TtsService extends SpeechService {
  TtsService({this.repeatWindow = const Duration(milliseconds: 1500)});

  final Duration repeatWindow;
  final FlutterTts _tts = FlutterTts();
  bool _available = false;
  bool _speaking = false;
  String? _lastText;
  DateTime? _lastAt;

  @override
  bool get available => _available;
  @override
  bool get speaking => _speaking;

  @override
  Future<void> init() async {
    try {
      final ok = await _tts.isLanguageAvailable('vi-VN');
      _available = ok == true || ok == 1;
      if (_available) {
        await _tts.setLanguage('vi-VN');
        await _tts.setPitch(1.0);
        await _tts.setVolume(0.9);
        await _tts.awaitSpeakCompletion(false);
      }
      _tts.setStartHandler(() {
        _speaking = true;
        notifyListeners();
      });
      void done() {
        _speaking = false;
        notifyListeners();
      }

      _tts.setCompletionHandler(done);
      _tts.setCancelHandler(done);
      _tts.setErrorHandler((_) => done());
    } catch (_) {
      _available = false;
    }
    notifyListeners();
  }

  @override
  Future<void> speak(String text, {double rate = 0.45}) async {
    if (!_available || text.trim().isEmpty) return;
    final now = DateTime.now();
    if (_lastText == text &&
        _lastAt != null &&
        now.difference(_lastAt!) < repeatWindow) {
      return; // cùng câu bị gõ lặp → bỏ qua
    }
    _lastText = text;
    _lastAt = now;
    try {
      await _tts.stop();
      await _tts.setSpeechRate(rate);
      await _tts.speak(text);
    } catch (_) {
      // TTS lỗi không được làm hỏng luồng giao tiếp bằng hình.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    _speaking = false;
    notifyListeners();
  }
}

/// Dùng cho kiểm thử / thiết bị không có TTS.
class SilentSpeechService extends SpeechService {
  final List<String> spoken = [];
  @override
  bool get available => true;
  @override
  bool get speaking => false;
  @override
  Future<void> init() async {}
  @override
  Future<void> speak(String text, {double rate = 0.45}) async =>
      spoken.add(text);
  @override
  Future<void> stop() async {}
}
