import '../core/icon_catalog.dart';

/// Bản nháp câu chuyện sau khi đã được xác thực (từ AI hoặc mẫu cục bộ).
class StoryDraft {
  const StoryDraft({
    required this.title,
    required this.steps,
    required this.caregiverTip,
    required this.source,
  });

  final String title;
  final List<DraftStep> steps;
  final String caregiverTip;
  final String source; // 'ai' | 'template'
}

class DraftStep {
  const DraftStep(this.text, this.icon);
  final String text;
  final String icon;
}

class ValidationError implements Exception {
  ValidationError(this.problems);
  final List<String> problems;
  @override
  String toString() => problems.join('; ');
}

/// Ràng buộc đầu vào/đầu ra theo Mục 6.6 và kiểm soát nội dung Mục 7.4–7.5.
class StoryValidator {
  StoryValidator._();

  static const scenarioMin = 8;
  static const scenarioMax = 240;
  static const maxPrefs = 5;
  static const prefMax = 80;
  static const titleMin = 3;
  static const titleMax = 70;
  static const stepsMin = 4;
  static const stepsMax = 6;
  static const stepMin = 3;
  static const stepMax = 160;
  static const tipMin = 3;
  static const tipMax = 240;

  /// Góp ý review: mỗi bước nên là MỘT câu đơn ngắn (≤ 15 từ).
  static const recommendedWordsPerStep = 15;

  /// Cụm từ áp đặt, phán xét hoặc mang tính y khoa – không được xuất hiện
  /// trong nội dung trẻ xem (Mục 7.4).
  static const _forbidden = [
    'chẩn đoán',
    'điều trị',
    'trị liệu',
    'uống thuốc',
    'con phải',
    'bắt buộc',
    'không được khóc',
    'phải ngồi yên',
    'phải nhìn',
    'nhìn vào mắt',
    'con sẽ cảm thấy',
    'con sẽ thấy vui',
    'con sẽ không sợ',
    'ngoan',
    'hư',
    'bị phạt',
    'trừng phạt',
    'thất bại',
  ];

  static List<String> validateRequest({
    required String scenario,
    required String language,
    required List<String> sensoryPreferences,
  }) {
    final problems = <String>[];
    final s = scenario.trim();
    if (s.length < scenarioMin || s.length > scenarioMax) {
      problems.add('Mô tả cần dài từ $scenarioMin đến $scenarioMax ký tự.');
    }
    if (language != 'vi' && language != 'en') {
      problems.add('Ngôn ngữ chỉ nhận "vi" hoặc "en".');
    }
    if (sensoryPreferences.length > maxPrefs) {
      problems.add('Tối đa $maxPrefs lưu ý cảm giác.');
    }
    for (final p in sensoryPreferences) {
      final t = p.trim();
      if (t.isEmpty || t.length > prefMax) {
        problems.add('Mỗi lưu ý dài từ 1 đến $prefMax ký tự.');
        break;
      }
    }
    return problems;
  }

  /// Xác thực phản hồi JSON từ máy chủ. Không mặc định coi là hợp lệ chỉ vì
  /// có định dạng JSON. Ném [ValidationError] nếu sai lược đồ.
  static StoryDraft parseResponse(Object? json) {
    final problems = <String>[];
    if (json is! Map) throw ValidationError(['Phản hồi không phải đối tượng JSON.']);

    final title = json['title'];
    if (title is! String ||
        title.trim().length < titleMin ||
        title.trim().length > titleMax) {
      problems.add('Tiêu đề không hợp lệ.');
    }

    final rawSteps = json['steps'];
    final steps = <DraftStep>[];
    if (rawSteps is! List ||
        rawSteps.length < stepsMin ||
        rawSteps.length > stepsMax) {
      problems.add('Câu chuyện cần $stepsMin–$stepsMax bước.');
    } else {
      for (final st in rawSteps) {
        if (st is! Map) {
          problems.add('Bước không hợp lệ.');
          continue;
        }
        final text = st['text'];
        final icon = st['icon'];
        if (text is! String ||
            text.trim().length < stepMin ||
            text.trim().length > stepMax) {
          problems.add('Nội dung bước không hợp lệ.');
          continue;
        }
        if (icon is! String || !IconCatalog.storyAllowlist.contains(icon)) {
          problems.add('Biểu tượng ngoài danh sách cho phép.');
          continue;
        }
        steps.add(DraftStep(text.trim(), icon));
      }
    }

    final tip = json['caregiver_tip'];
    if (tip is! String ||
        tip.trim().length < tipMin ||
        tip.trim().length > tipMax) {
      problems.add('Ghi chú cho người chăm sóc không hợp lệ.');
    }

    if (json['requires_review'] != true) {
      problems.add('Phản hồi phải yêu cầu người chăm sóc duyệt.');
    }

    if (problems.isEmpty) {
      final childText = [title as String, ...steps.map((s) => s.text)];
      final bad = childText.expand(findForbidden).toSet();
      if (bad.isNotEmpty) {
        problems.add('Nội dung có cụm từ không phù hợp: ${bad.join(', ')}');
      }
    }

    if (problems.isNotEmpty) throw ValidationError(problems);
    return StoryDraft(
      title: (title as String).trim(),
      steps: steps,
      caregiverTip: (tip as String).trim(),
      source: 'ai',
    );
  }

  static List<String> findForbidden(String text) {
    final lower = ' ${text.toLowerCase()} ';
    return _forbidden.where((f) {
      // so khớp theo ranh giới từ để "hư" không khớp "những"
      final pattern = RegExp('(^|[\\s,.!?;:"“”])${RegExp.escape(f)}(?=[\\s,.!?;:"“”]|\$)');
      return pattern.hasMatch(lower);
    }).toList();
  }

  static int wordCount(String text) =>
      text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

  /// Cảnh báo chất lượng (không chặn): câu quá dài, nhiều câu trong một bước.
  static List<String> stepWarnings(String text) {
    final w = <String>[];
    if (wordCount(text) > recommendedWordsPerStep) {
      w.add('Bước dài hơn $recommendedWordsPerStep từ – nên rút gọn.');
    }
    final sentences = text
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .length;
    if (sentences > 1) w.add('Nên giữ một câu đơn cho mỗi bước.');
    if (findForbidden(text).isNotEmpty) {
      w.add('Có cụm từ mang tính áp đặt hoặc y khoa.');
    }
    return w;
  }

  /// Cảnh báo dữ liệu nhận diện trước khi gửi AI (FR-M4-09, Mục 8.3).
  static List<String> privacyWarnings(String text) {
    final w = <String>[];
    if (RegExp(r'(\+?84|0)\d{8,10}').hasMatch(text.replaceAll(' ', ''))) {
      w.add('Có vẻ chứa số điện thoại.');
    }
    if (RegExp(r'[\w.+-]+@[\w-]+\.[\w.]+').hasMatch(text)) {
      w.add('Có vẻ chứa địa chỉ email.');
    }
    final lower = text.toLowerCase();
    const addressHints = [
      'số nhà',
      'đường ',
      'phường',
      'quận',
      'huyện',
      'ngõ',
      'hẻm',
      'chung cư'
    ];
    if (addressHints.any(lower.contains)) {
      w.add('Có vẻ chứa địa chỉ.');
    }
    if (RegExp(r'(tên (con|bé|cháu) là|bé tên|con tên)').hasMatch(lower)) {
      w.add('Có vẻ chứa tên của trẻ.');
    }
    if (RegExp(r'(trường|lớp) [A-ZĐ0-9]').hasMatch(text)) {
      w.add('Có vẻ chứa tên trường/lớp.');
    }
    return w;
  }
}
