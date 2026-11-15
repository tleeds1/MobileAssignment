import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/icon_catalog.dart';
import '../../core/theme.dart';

/// Hiển thị ảnh thật (nếu người chăm sóc thêm) hoặc biểu tượng.
class Pictogram extends StatelessWidget {
  const Pictogram({
    super.key,
    required this.iconKey,
    this.imageRef,
    this.size = 64,
    this.color = AppColors.primary,
    this.background,
    this.radius = 16,
  });

  final String iconKey;
  final String? imageRef;
  final double size;
  final Color color;
  final Color? background;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final path = imageRef;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _icon(),
        ),
      );
    }
    return _icon();
  }

  Widget _icon() {
    final icon = Icon(IconCatalog.of(iconKey), size: size * 0.8, color: color);
    if (background == null) {
      return SizedBox(width: size, height: size, child: Center(child: icon));
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(child: icon),
    );
  }
}
