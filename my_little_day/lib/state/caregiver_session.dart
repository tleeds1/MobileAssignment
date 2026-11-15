import 'dart:async';

import 'package:flutter/foundation.dart';

/// Phiên người chăm sóc (BR-11, UI-07): tự khóa khi không thao tác quá
/// [timeout]; khi khóa, ứng dụng quay về chế độ trẻ và ẩn thao tác quản lý.
class CaregiverSession extends ChangeNotifier {
  CaregiverSession({this.timeout = const Duration(minutes: 5)});

  Duration timeout;
  bool _unlocked = false;
  DateTime? _lastActivity;
  Timer? _ticker;

  bool get unlocked => _unlocked && !_expired;

  bool get _expired =>
      _lastActivity == null ||
      DateTime.now().difference(_lastActivity!) > timeout;

  void unlock() {
    _unlocked = true;
    _lastActivity = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_unlocked && _expired) lock();
    });
    notifyListeners();
  }

  /// Gọi khi người chăm sóc thao tác để gia hạn phiên.
  void touch() {
    if (_unlocked) _lastActivity = DateTime.now();
  }

  void lock() {
    if (!_unlocked) return;
    _unlocked = false;
    _lastActivity = null;
    _ticker?.cancel();
    _ticker = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
