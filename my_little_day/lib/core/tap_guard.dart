/// Bộ lọc chống gõ lặp (debounce/throttle) – góp ý: trẻ có thể gõ liên thanh
/// hoặc giữ ngón tay lâu, gây phát nhiều luồng TTS chồng chéo.
class TapGuard {
  TapGuard({this.interval = const Duration(milliseconds: 600)});

  final Duration interval;
  final Map<String, DateTime> _last = {};

  /// Trả về true nếu thao tác với [key] được phép chạy ngay bây giờ.
  bool allow([String key = '_']) {
    final now = DateTime.now();
    final prev = _last[key];
    if (prev != null && now.difference(prev) < interval) return false;
    _last[key] = now;
    return true;
  }

  void reset() => _last.clear();
}
