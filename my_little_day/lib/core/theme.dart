import 'package:flutter/material.dart';

/// Bảng màu theo Mục 5.3 của đặc tả (Bảng 14).
class AppColors {
  AppColors._();

  static const background = Color(0xFFF8F9F6);
  static const text = Color(0xFF203B37);
  static const primary = Color(0xFF286B5C);
  static const accentBg = Color(0xFFE1EEE9);
  static const lightBlue = Color(0xFFE9F2F7);
  static const cream = Color(0xFFF6EFDF);
  static const surface = Colors.white;
  static const muted = Color(0xFF5B6E6A);
  static const border = Color(0xFFD5DFDB);

  /// Màu bóng đổ đậm hơn để tạo chiều sâu cơ học (góp ý "giao diện phẳng").
  static const shadow = Color(0x33203B37);
}

/// Mã màu viền thẻ theo tinh thần Fitzgerald Key (góp ý M2).
/// Màu luôn đi kèm biểu tượng nhóm + nhãn, không dùng màu làm tín hiệu duy nhất.
class FitzgeraldColors {
  FitzgeraldColors._();

  static const person = Color(0xFFE6C34A); // người / đại từ – vàng
  static const action = Color(0xFF5FA36B); // động từ – xanh lá
  static const thing = Color(0xFFE39A4C); // danh từ – cam
  static const describe = Color(0xFF5B8FC7); // tính từ / mô tả – xanh dương
  static const social = Color(0xFFB57BC4); // giao tiếp xã hội – tím
  static const help = Color(0xFFD9A520); // trợ giúp – vàng nghệ
  static const urgent = Color(0xFFC8553D); // dừng / đau / từ chối – đỏ gạch
}

ThemeData buildAppTheme({double textScale = 1.0}) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      background: AppColors.background,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(48, 56),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        minimumSize: const Size(48, 56),
        side: const BorderSide(color: AppColors.border, width: 1.5),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      indicatorColor: AppColors.accentBg,
      labelTextStyle: MaterialStatePropertyAll(
        TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

/// Khoảng cách theo lưới 8dp.
class Gap {
  Gap._();
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}
