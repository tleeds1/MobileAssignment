import 'package:flutter/foundation.dart';

import '../data/models.dart';
import '../data/repositories/settings_repository.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._repo, AppSettings initial) : _value = initial;

  /// Bộ điều khiển chỉ dùng cho bản xem trước – không ghi vào CSDL.
  SettingsController.preview(AppSettings initial)
      : _repo = null,
        _value = initial;

  final SettingsRepository? _repo;
  AppSettings _value;

  AppSettings get value => _value;

  /// Chỉ thông báo thành công sau khi kho dữ liệu xác nhận (Mục 6.5).
  Future<void> update(AppSettings next) async {
    await _repo?.save(next);
    _value = next;
    notifyListeners();
  }

  /// Dùng sau khi đặt lại toàn bộ dữ liệu.
  Future<void> reload() async {
    final repo = _repo;
    if (repo == null) return;
    _value = await repo.load();
    notifyListeners();
  }
}
