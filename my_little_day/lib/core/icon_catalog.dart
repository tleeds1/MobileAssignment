import 'package:flutter/material.dart';

/// Danh mục biểu tượng dùng trong ứng dụng. `iconKey` được lưu trong CSDL,
/// không lưu IconData trực tiếp để dữ liệu ổn định qua các phiên bản.
class IconCatalog {
  IconCatalog._();

  /// Danh sách icon được phép cho câu chuyện AI (Mục 6.6) – KHÔNG thay đổi
  /// nếu chưa cập nhật hợp đồng API.
  static const storyAllowlist = <String>[
    'home',
    'ear',
    'parent',
    'clock',
    'rest',
    'person',
    'car',
    'doctor',
    'scissors',
    'smile',
    'book',
    'water',
    'school',
    'done',
  ];

  static const Map<String, IconData> _icons = {
    // Story allowlist
    'home': Icons.home_rounded,
    'ear': Icons.hearing_rounded,
    'parent': Icons.family_restroom_rounded,
    'clock': Icons.schedule_rounded,
    'rest': Icons.bed_rounded,
    'person': Icons.person_rounded,
    'car': Icons.directions_car_rounded,
    'doctor': Icons.medical_services_rounded,
    'scissors': Icons.content_cut_rounded,
    'smile': Icons.sentiment_satisfied_alt_rounded,
    'book': Icons.menu_book_rounded,
    'water': Icons.local_drink_rounded,
    'school': Icons.school_rounded,
    'done': Icons.check_circle_rounded,
    // Hoạt động
    'breakfast': Icons.ramen_dining_rounded,
    'food': Icons.restaurant_rounded,
    'toothbrush': Icons.brush_rounded,
    'bath': Icons.bathtub_rounded,
    'clothes': Icons.checkroom_rounded,
    'play': Icons.toys_rounded,
    'sleep': Icons.nights_stay_rounded,
    'music': Icons.music_note_rounded,
    'park': Icons.park_rounded,
    'draw': Icons.palette_rounded,
    'bus': Icons.directions_bus_rounded,
    'tv': Icons.tv_rounded,
    // Thẻ giao tiếp
    'toilet': Icons.wc_rounded,
    'help': Icons.back_hand_rounded,
    'pain': Icons.healing_rounded,
    'no': Icons.cancel_rounded,
    'stop': Icons.pan_tool_rounded,
    'yes': Icons.thumb_up_alt_rounded,
    'want': Icons.volunteer_activism_rounded,
    'more': Icons.add_circle_rounded,
    'hug': Icons.favorite_rounded,
    'hungry': Icons.lunch_dining_rounded,
    'juice': Icons.emoji_food_beverage_rounded,
    'fruit': Icons.apple_rounded,
    'quiet': Icons.volume_off_rounded,
    'hot': Icons.thermostat_rounded,
    'cold': Icons.ac_unit_rounded,
    'big': Icons.open_in_full_rounded,
    'me': Icons.face_rounded,
    'you': Icons.person_outline_rounded,
    'hello': Icons.waving_hand_rounded,
    'thanks': Icons.emoji_people_rounded,
    'go': Icons.directions_walk_rounded,
    'eat': Icons.restaurant_menu_rounded,
    'drink': Icons.local_cafe_rounded,
    // Cảm xúc / cảm giác cơ thể
    'happy': Icons.sentiment_very_satisfied_rounded,
    'calm': Icons.self_improvement_rounded,
    'worried': Icons.sentiment_neutral_rounded,
    'sad': Icons.sentiment_dissatisfied_rounded,
    'upset': Icons.sentiment_very_dissatisfied_rounded,
    'tired': Icons.airline_seat_flat_rounded,
    'headache': Icons.psychology_rounded,
    'hot_body': Icons.local_fire_department_rounded,
    'shout': Icons.campaign_rounded,
    'tummy': Icons.sick_rounded,
    'unknown': Icons.help_outline_rounded,
    'skip': Icons.skip_next_rounded,
    'star': Icons.star_rounded,
  };

  static IconData of(String? key) =>
      _icons[key] ?? Icons.image_outlined;

  static bool exists(String? key) => key != null && _icons.containsKey(key);

  static List<String> get allKeys => _icons.keys.toList();

  /// Nhóm gợi ý cho trình chọn icon của người chăm sóc.
  static const activityKeys = [
    'breakfast',
    'food',
    'toothbrush',
    'bath',
    'clothes',
    'school',
    'bus',
    'car',
    'play',
    'park',
    'draw',
    'music',
    'book',
    'tv',
    'sleep',
    'rest',
    'doctor',
    'scissors',
    'home',
    'star',
  ];

  static const cardKeys = [
    'water',
    'juice',
    'drink',
    'eat',
    'hungry',
    'fruit',
    'toilet',
    'rest',
    'help',
    'pain',
    'no',
    'stop',
    'yes',
    'want',
    'more',
    'hug',
    'quiet',
    'hot',
    'cold',
    'big',
    'me',
    'you',
    'hello',
    'thanks',
    'go',
    'play',
    'music',
    'book',
  ];

  static const emotionKeys = [
    'happy',
    'calm',
    'worried',
    'sad',
    'upset',
    'tired',
    'headache',
    'hot_body',
    'shout',
    'tummy',
    'pain',
    'unknown',
  ];
}
