/// Tiện ích ngày theo BR-09: ngày lịch dùng `localDate` (yyyy-MM-dd) theo múi giờ thiết bị.
class LocalDate {
  LocalDate._();

  static String of(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  static String today() => of(DateTime.now());

  static DateTime parse(String localDate) {
    final parts = localDate.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  /// 1 = Thứ Hai ... 7 = Chủ nhật (giống DateTime.weekday).
  static int weekdayOf(String localDate) => parse(localDate).weekday;

  static String addDays(String localDate, int days) =>
      of(parse(localDate).add(Duration(days: days)));

  static const _weekdayNames = {
    1: 'Thứ Hai',
    2: 'Thứ Ba',
    3: 'Thứ Tư',
    4: 'Thứ Năm',
    5: 'Thứ Sáu',
    6: 'Thứ Bảy',
    7: 'Chủ nhật',
  };

  static const _weekdayShort = {
    1: 'T2',
    2: 'T3',
    3: 'T4',
    4: 'T5',
    5: 'T6',
    6: 'T7',
    7: 'CN',
  };

  static String weekdayName(int weekday) => _weekdayNames[weekday] ?? '';
  static String weekdayShort(int weekday) => _weekdayShort[weekday] ?? '';

  static String friendly(String localDate) {
    final today = LocalDate.today();
    final name = weekdayName(weekdayOf(localDate));
    if (localDate == today) return 'Hôm nay · $name';
    if (localDate == addDays(today, 1)) return 'Ngày mai · $name';
    if (localDate == addDays(today, -1)) return 'Hôm qua · $name';
    final d = parse(localDate);
    return '$name, ${d.day}/${d.month}';
  }

  /// Thời gian ISO 8601 kèm độ lệch múi giờ (Mục 6.5).
  static String isoNow() => isoOf(DateTime.now());

  static String isoOf(DateTime dt) {
    final local = dt.toLocal();
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final h = offset.inHours.abs().toString().padLeft(2, '0');
    final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
    final base = local.toIso8601String().split('.').first;
    return '$base$sign$h:$m';
  }

  /// "HH:mm" -> số phút trong ngày; null nếu không hợp lệ.
  static int? minutesOf(String? hhmm) {
    if (hhmm == null || hhmm.isEmpty) return null;
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }
}
