import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories/emotion_repository.dart';
import 'settings_controller.dart';

class EmotionController extends ChangeNotifier {
  EmotionController(this.repo, this._settings);

  final EmotionRepository repo;
  final SettingsController _settings;

  List<EmotionOption> _options = const [];
  List<EmotionOption> get options => _options.where((o) => !o.hidden).toList();
  List<EmotionOption> get allOptions => _options;

  Future<void> load() async {
    _options = await repo.options();
    notifyListeners();
  }

  /// Chỉ tạo bản ghi khi trẻ CHỌN + XÁC NHẬN và người chăm sóc đã bật lưu
  /// lịch sử (UC-CH-04, FR-M3-04). Trả về true nếu đã lưu.
  Future<bool> confirm(EmotionOption option) async {
    if (!_settings.value.emotionHistoryEnabled) return false;
    await repo.addEntry(option.label);
    return true;
  }

  /// Áp dụng thời hạn lưu giữ chỉ khi đã có chính sách được chọn (TC-10).
  Future<void> applyRetention() async {
    final days = _settings.value.dataRetentionDays;
    if (days != null && days > 0) {
      await repo.purgeOlderThan(days);
    }
  }
}
