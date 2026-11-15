// Mô hình dữ liệu theo Mục 6.4 (Bảng 17) và các bổ sung cần cho FR-M1-12,
// FR-M5-03 cùng các góp ý review. Viết tương thích Dart 2.18.

import 'dart:convert';

// ---------------------------------------------------------------------------
// AppSettings
// ---------------------------------------------------------------------------

enum ScheduleViewMode { single, nowNext, fullDay }

class AppSettings {
  const AppSettings({
    this.preferredName = 'con',
    this.textScale = 1.0,
    this.quietMode = false,
    this.ttsEnabled = true,
    this.ttsRate = 0.45,
    this.vibrationEnabled = false,
    this.reduceMotion = false,
    this.showLabels = true,
    this.cardsPerScreen = 6,
    this.scheduleViewMode = ScheduleViewMode.nowNext,
    this.sentenceStripEnabled = true,
    this.emotionHistoryEnabled = false,
    this.dataRetentionDays,
    this.cardUsageLogEnabled = false,
    this.autoTimeCurrent = false,
    this.focusLock = false,
    this.doneNeedsHold = true,
    this.supportSuggestionEnabled = true,
    this.onboardingDone = false,
    this.aiEnabled = true,
    this.aiServerUrl = '',
    this.sessionTimeoutMinutes = 5,
  });

  final String preferredName;
  final double textScale; // 1.0 – 1.3 (NFR-05)
  final bool quietMode;
  final bool ttsEnabled;
  final double ttsRate;
  final bool vibrationEnabled;
  final bool reduceMotion;
  final bool showLabels;
  final int cardsPerScreen; // 4 / 6 / 8
  final ScheduleViewMode scheduleViewMode;
  final bool sentenceStripEnabled;
  final bool emotionHistoryEnabled;

  /// null = chưa có chính sách được duyệt → không tự xóa (NFR-25, TC-10).
  final int? dataRetentionDays;
  final bool cardUsageLogEnabled;
  final bool autoTimeCurrent;

  /// Chế độ khóa tập trung: ẩn thanh điều hướng của trẻ.
  final bool focusLock;

  /// Nút "Xong rồi" cần giữ ~1 giây (chống chạm nhầm).
  final bool doneNeedsHold;

  /// Sau check-in "Buồn/Khó chịu"... gợi ý thẻ xoa dịu.
  final bool supportSuggestionEnabled;
  final bool onboardingDone;
  final bool aiEnabled;
  final String aiServerUrl;
  final int sessionTimeoutMinutes;

  /// TTS chỉ hoạt động khi bật và không ở chế độ yên tĩnh (Mục 5.5).
  bool get canSpeak => ttsEnabled && !quietMode;
  bool get animationsOn => !reduceMotion;

  AppSettings copyWith({
    String? preferredName,
    double? textScale,
    bool? quietMode,
    bool? ttsEnabled,
    double? ttsRate,
    bool? vibrationEnabled,
    bool? reduceMotion,
    bool? showLabels,
    int? cardsPerScreen,
    ScheduleViewMode? scheduleViewMode,
    bool? sentenceStripEnabled,
    bool? emotionHistoryEnabled,
    int? dataRetentionDays,
    bool clearRetention = false,
    bool? cardUsageLogEnabled,
    bool? autoTimeCurrent,
    bool? focusLock,
    bool? doneNeedsHold,
    bool? supportSuggestionEnabled,
    bool? onboardingDone,
    bool? aiEnabled,
    String? aiServerUrl,
    int? sessionTimeoutMinutes,
  }) {
    return AppSettings(
      preferredName: preferredName ?? this.preferredName,
      textScale: textScale ?? this.textScale,
      quietMode: quietMode ?? this.quietMode,
      ttsEnabled: ttsEnabled ?? this.ttsEnabled,
      ttsRate: ttsRate ?? this.ttsRate,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      showLabels: showLabels ?? this.showLabels,
      cardsPerScreen: cardsPerScreen ?? this.cardsPerScreen,
      scheduleViewMode: scheduleViewMode ?? this.scheduleViewMode,
      sentenceStripEnabled: sentenceStripEnabled ?? this.sentenceStripEnabled,
      emotionHistoryEnabled:
          emotionHistoryEnabled ?? this.emotionHistoryEnabled,
      dataRetentionDays: clearRetention
          ? null
          : (dataRetentionDays ?? this.dataRetentionDays),
      cardUsageLogEnabled: cardUsageLogEnabled ?? this.cardUsageLogEnabled,
      autoTimeCurrent: autoTimeCurrent ?? this.autoTimeCurrent,
      focusLock: focusLock ?? this.focusLock,
      doneNeedsHold: doneNeedsHold ?? this.doneNeedsHold,
      supportSuggestionEnabled:
          supportSuggestionEnabled ?? this.supportSuggestionEnabled,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      aiEnabled: aiEnabled ?? this.aiEnabled,
      aiServerUrl: aiServerUrl ?? this.aiServerUrl,
      sessionTimeoutMinutes:
          sessionTimeoutMinutes ?? this.sessionTimeoutMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'preferredName': preferredName,
        'textScale': textScale,
        'quietMode': quietMode,
        'ttsEnabled': ttsEnabled,
        'ttsRate': ttsRate,
        'vibrationEnabled': vibrationEnabled,
        'reduceMotion': reduceMotion,
        'showLabels': showLabels,
        'cardsPerScreen': cardsPerScreen,
        'scheduleViewMode': scheduleViewMode.name,
        'sentenceStripEnabled': sentenceStripEnabled,
        'emotionHistoryEnabled': emotionHistoryEnabled,
        'dataRetentionDays': dataRetentionDays,
        'cardUsageLogEnabled': cardUsageLogEnabled,
        'autoTimeCurrent': autoTimeCurrent,
        'focusLock': focusLock,
        'doneNeedsHold': doneNeedsHold,
        'supportSuggestionEnabled': supportSuggestionEnabled,
        'onboardingDone': onboardingDone,
        'aiEnabled': aiEnabled,
        'aiServerUrl': aiServerUrl,
        'sessionTimeoutMinutes': sessionTimeoutMinutes,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    T pick<T>(String k, T fallback) {
      final v = j[k];
      return v is T ? v : fallback;
    }

    final cards = pick<int>('cardsPerScreen', d.cardsPerScreen);
    final scale = (j['textScale'] is num)
        ? (j['textScale'] as num).toDouble()
        : d.textScale;
    final rate =
        (j['ttsRate'] is num) ? (j['ttsRate'] as num).toDouble() : d.ttsRate;
    return AppSettings(
      preferredName: pick<String>('preferredName', d.preferredName),
      textScale: scale.clamp(1.0, 1.3).toDouble(),
      quietMode: pick<bool>('quietMode', d.quietMode),
      ttsEnabled: pick<bool>('ttsEnabled', d.ttsEnabled),
      ttsRate: rate,
      vibrationEnabled: pick<bool>('vibrationEnabled', d.vibrationEnabled),
      reduceMotion: pick<bool>('reduceMotion', d.reduceMotion),
      showLabels: pick<bool>('showLabels', d.showLabels),
      cardsPerScreen: const [4, 6, 8].contains(cards) ? cards : 6,
      scheduleViewMode: ScheduleViewMode.values.firstWhere(
        (m) => m.name == j['scheduleViewMode'],
        orElse: () => d.scheduleViewMode,
      ),
      sentenceStripEnabled:
          pick<bool>('sentenceStripEnabled', d.sentenceStripEnabled),
      emotionHistoryEnabled:
          pick<bool>('emotionHistoryEnabled', d.emotionHistoryEnabled),
      dataRetentionDays: j['dataRetentionDays'] is int
          ? j['dataRetentionDays'] as int
          : null,
      cardUsageLogEnabled:
          pick<bool>('cardUsageLogEnabled', d.cardUsageLogEnabled),
      autoTimeCurrent: pick<bool>('autoTimeCurrent', d.autoTimeCurrent),
      focusLock: pick<bool>('focusLock', d.focusLock),
      doneNeedsHold: pick<bool>('doneNeedsHold', d.doneNeedsHold),
      supportSuggestionEnabled:
          pick<bool>('supportSuggestionEnabled', d.supportSuggestionEnabled),
      onboardingDone: pick<bool>('onboardingDone', d.onboardingDone),
      aiEnabled: pick<bool>('aiEnabled', d.aiEnabled),
      aiServerUrl: pick<String>('aiServerUrl', d.aiServerUrl),
      sessionTimeoutMinutes:
          pick<int>('sessionTimeoutMinutes', d.sessionTimeoutMinutes),
    );
  }

  String encode() => jsonEncode(toJson());
  static AppSettings decode(String s) =>
      AppSettings.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

// ---------------------------------------------------------------------------
// M1 – Lịch trình
// ---------------------------------------------------------------------------

class RoutineTemplate {
  const RoutineTemplate({
    required this.id,
    required this.title,
    required this.weekdays,
    required this.updatedAt,
    this.isSample = false,
  });

  final String id;
  final String title;

  /// 1 = Thứ Hai ... 7 = Chủ nhật.
  final List<int> weekdays;
  final String updatedAt;
  final bool isSample;

  RoutineTemplate copyWith({String? title, List<int>? weekdays, String? updatedAt}) =>
      RoutineTemplate(
        id: id,
        title: title ?? this.title,
        weekdays: weekdays ?? this.weekdays,
        updatedAt: updatedAt ?? this.updatedAt,
        isSample: isSample,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'weekdays': weekdays.join(','),
        'updatedAt': updatedAt,
        'isSample': isSample ? 1 : 0,
      };

  factory RoutineTemplate.fromRow(Map<String, Object?> r) => RoutineTemplate(
        id: r['id'] as String,
        title: r['title'] as String,
        weekdays: (r['weekdays'] as String? ?? '')
            .split(',')
            .where((s) => s.isNotEmpty)
            .map(int.parse)
            .toList(),
        updatedAt: r['updatedAt'] as String,
        isSample: (r['isSample'] as int? ?? 0) == 1,
      );
}

class Activity {
  const Activity({
    required this.id,
    this.templateId,
    this.localDate,
    required this.title,
    this.subtitle = '',
    this.iconKey = 'star',
    this.imageRef,
    this.optionalTime,
    required this.position,
    this.note = '',
    this.isSample = false,
  });

  final String id;

  /// Thuộc mẫu lịch (lặp theo thứ) …
  final String? templateId;

  /// … hoặc là hoạt động một lần cho một ngày cụ thể.
  final String? localDate;
  final String title;
  final String subtitle;
  final String iconKey;
  final String? imageRef;
  final String? optionalTime; // "HH:mm"
  final int position;
  final String note; // chỉ hiển thị cho người chăm sóc
  final bool isSample;

  bool get isOneOff => templateId == null;

  Activity copyWith({
    String? id,
    String? templateId,
    String? localDate,
    String? title,
    String? subtitle,
    String? iconKey,
    String? imageRef,
    bool clearImage = false,
    String? optionalTime,
    bool clearTime = false,
    int? position,
    String? note,
  }) =>
      Activity(
        id: id ?? this.id,
        templateId: templateId ?? this.templateId,
        localDate: localDate ?? this.localDate,
        title: title ?? this.title,
        subtitle: subtitle ?? this.subtitle,
        iconKey: iconKey ?? this.iconKey,
        imageRef: clearImage ? null : (imageRef ?? this.imageRef),
        optionalTime: clearTime ? null : (optionalTime ?? this.optionalTime),
        position: position ?? this.position,
        note: note ?? this.note,
        isSample: isSample,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'templateId': templateId,
        'localDate': localDate,
        'title': title,
        'subtitle': subtitle,
        'iconKey': iconKey,
        'imageRef': imageRef,
        'optionalTime': optionalTime,
        'position': position,
        'note': note,
        'isSample': isSample ? 1 : 0,
      };

  factory Activity.fromRow(Map<String, Object?> r) => Activity(
        id: r['id'] as String,
        templateId: r['templateId'] as String?,
        localDate: r['localDate'] as String?,
        title: r['title'] as String,
        subtitle: r['subtitle'] as String? ?? '',
        iconKey: r['iconKey'] as String? ?? 'star',
        imageRef: r['imageRef'] as String?,
        optionalTime: r['optionalTime'] as String?,
        position: r['position'] as int? ?? 0,
        note: r['note'] as String? ?? '',
        isSample: (r['isSample'] as int? ?? 0) == 1,
      );
}

enum CompletionStatus { done, later, skipped }

class ActivityCompletion {
  const ActivityCompletion({
    required this.id,
    required this.activityId,
    required this.localDate,
    required this.status,
    required this.completedAt,
  });

  final String id;
  final String activityId;
  final String localDate;
  final CompletionStatus status;
  final String completedAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'activityId': activityId,
        'localDate': localDate,
        'status': status.name,
        'completedAt': completedAt,
      };

  factory ActivityCompletion.fromRow(Map<String, Object?> r) =>
      ActivityCompletion(
        id: r['id'] as String,
        activityId: r['activityId'] as String,
        localDate: r['localDate'] as String,
        status: CompletionStatus.values.firstWhere(
          (s) => s.name == r['status'],
          orElse: () => CompletionStatus.done,
        ),
        completedAt: r['completedAt'] as String,
      );
}

/// Thay đổi lịch trong một ngày (UC-CH-03, FR-M1-07, FR-M1-12).
enum ChangeType { changed, postponed, cancelled, replaced, undecided }

extension ChangeTypeLabel on ChangeType {
  String get label {
    switch (this) {
      case ChangeType.changed:
        return 'Đổi';
      case ChangeType.postponed:
        return 'Hoãn';
      case ChangeType.cancelled:
        return 'Hủy';
      case ChangeType.replaced:
        return 'Thay bằng';
      case ChangeType.undecided:
        return 'Chưa xác định';
    }
  }
}

class ScheduleChange {
  const ScheduleChange({
    required this.id,
    required this.activityId,
    required this.localDate,
    required this.type,
    this.replacementActivityId,
    this.message = '',
    this.linkedStoryId,
    this.linkedCardId,
    required this.createdAt,
  });

  final String id;
  final String activityId;
  final String localDate;
  final ChangeType type;
  final String? replacementActivityId;
  final String message;
  final String? linkedStoryId;
  final String? linkedCardId;
  final String createdAt;

  Map<String, Object?> toRow() => {
        'id': id,
        'activityId': activityId,
        'localDate': localDate,
        'type': type.name,
        'replacementActivityId': replacementActivityId,
        'message': message,
        'linkedStoryId': linkedStoryId,
        'linkedCardId': linkedCardId,
        'createdAt': createdAt,
      };

  factory ScheduleChange.fromRow(Map<String, Object?> r) => ScheduleChange(
        id: r['id'] as String,
        activityId: r['activityId'] as String,
        localDate: r['localDate'] as String,
        type: ChangeType.values.firstWhere(
          (t) => t.name == r['type'],
          orElse: () => ChangeType.changed,
        ),
        replacementActivityId: r['replacementActivityId'] as String?,
        message: r['message'] as String? ?? '',
        linkedStoryId: r['linkedStoryId'] as String?,
        linkedCardId: r['linkedCardId'] as String?,
        createdAt: r['createdAt'] as String,
      );
}

// ---------------------------------------------------------------------------
// M2 – Thẻ giao tiếp
// ---------------------------------------------------------------------------

/// Nhóm thẻ theo tinh thần Fitzgerald Key.
enum CardCategory { person, action, thing, describe, social, help, urgent }

extension CardCategoryInfo on CardCategory {
  String get label {
    switch (this) {
      case CardCategory.person:
        return 'Người';
      case CardCategory.action:
        return 'Hành động';
      case CardCategory.thing:
        return 'Đồ vật';
      case CardCategory.describe:
        return 'Mô tả';
      case CardCategory.social:
        return 'Giao tiếp';
      case CardCategory.help:
        return 'Trợ giúp';
      case CardCategory.urgent:
        return 'Dừng / Cần ngay';
    }
  }
}

class CommunicationCard {
  const CommunicationCard({
    required this.id,
    required this.label,
    this.speechText = '',
    this.iconKey = 'star',
    this.imageRef,
    this.category = CardCategory.thing,
    this.favorite = false,
    required this.position,
    this.hidden = false,
    this.isSample = false,
  });

  final String id;
  final String label;

  /// Nội dung đọc/hiển thị đầy đủ, ví dụ "Con muốn uống nước".
  final String speechText;
  final String iconKey;
  final String? imageRef;
  final CardCategory category;

  /// Thẻ ưu tiên (nghỉ, giúp, dừng, không, đau) – truy cập ≤ 2 thao tác.
  final bool favorite;

  /// Vị trí "ô" cố định trong thư viện. Đổi 4/6/8 thẻ/màn hình chỉ chia lại
  /// trang, KHÔNG đổi thứ tự tương đối → giữ trí nhớ cơ bắp của trẻ.
  final int position;
  final bool hidden;
  final bool isSample;

  String get spoken => speechText.trim().isEmpty ? label : speechText;

  CommunicationCard copyWith({
    String? label,
    String? speechText,
    String? iconKey,
    String? imageRef,
    bool clearImage = false,
    CardCategory? category,
    bool? favorite,
    int? position,
    bool? hidden,
  }) =>
      CommunicationCard(
        id: id,
        label: label ?? this.label,
        speechText: speechText ?? this.speechText,
        iconKey: iconKey ?? this.iconKey,
        imageRef: clearImage ? null : (imageRef ?? this.imageRef),
        category: category ?? this.category,
        favorite: favorite ?? this.favorite,
        position: position ?? this.position,
        hidden: hidden ?? this.hidden,
        isSample: isSample,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'label': label,
        'speechText': speechText,
        'iconKey': iconKey,
        'imageRef': imageRef,
        'category': category.name,
        'favorite': favorite ? 1 : 0,
        'position': position,
        'hidden': hidden ? 1 : 0,
        'isSample': isSample ? 1 : 0,
      };

  factory CommunicationCard.fromRow(Map<String, Object?> r) =>
      CommunicationCard(
        id: r['id'] as String,
        label: r['label'] as String,
        speechText: r['speechText'] as String? ?? '',
        iconKey: r['iconKey'] as String? ?? 'star',
        imageRef: r['imageRef'] as String?,
        category: CardCategory.values.firstWhere(
          (c) => c.name == r['category'],
          orElse: () => CardCategory.thing,
        ),
        favorite: (r['favorite'] as int? ?? 0) == 1,
        position: r['position'] as int? ?? 0,
        hidden: (r['hidden'] as int? ?? 0) == 1,
        isSample: (r['isSample'] as int? ?? 0) == 1,
      );
}

/// Bản ghi tần suất dùng thẻ – chỉ khi người chăm sóc bật (FR-M5-03).
class CardUsage {
  const CardUsage({
    required this.cardId,
    required this.label,
    required this.count,
    this.lastUsedAt,
  });
  final String cardId;
  final String label;
  final int count;
  final String? lastUsedAt;
}

// ---------------------------------------------------------------------------
// M3 – Check-in cảm xúc
// ---------------------------------------------------------------------------

enum EmotionKind { feeling, body }

/// Lựa chọn check-in do người chăm sóc cấu hình (không áp đặt hệ phân loại).
class EmotionOption {
  const EmotionOption({
    required this.id,
    required this.label,
    required this.iconKey,
    this.imageRef,
    this.kind = EmotionKind.feeling,
    this.suggestSupport = false,
    required this.position,
    this.hidden = false,
  });

  final String id;
  final String label;
  final String iconKey;
  final String? imageRef;
  final EmotionKind kind;

  /// Sau khi chọn → mở gợi ý xoa dịu (không phán xét, không bắt buộc).
  final bool suggestSupport;
  final int position;
  final bool hidden;

  EmotionOption copyWith({
    String? label,
    String? iconKey,
    String? imageRef,
    bool clearImage = false,
    EmotionKind? kind,
    bool? suggestSupport,
    int? position,
    bool? hidden,
  }) =>
      EmotionOption(
        id: id,
        label: label ?? this.label,
        iconKey: iconKey ?? this.iconKey,
        imageRef: clearImage ? null : (imageRef ?? this.imageRef),
        kind: kind ?? this.kind,
        suggestSupport: suggestSupport ?? this.suggestSupport,
        position: position ?? this.position,
        hidden: hidden ?? this.hidden,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'label': label,
        'iconKey': iconKey,
        'imageRef': imageRef,
        'kind': kind.name,
        'suggestSupport': suggestSupport ? 1 : 0,
        'position': position,
        'hidden': hidden ? 1 : 0,
      };

  factory EmotionOption.fromRow(Map<String, Object?> r) => EmotionOption(
        id: r['id'] as String,
        label: r['label'] as String,
        iconKey: r['iconKey'] as String? ?? 'unknown',
        imageRef: r['imageRef'] as String?,
        kind: EmotionKind.values.firstWhere(
          (k) => k.name == r['kind'],
          orElse: () => EmotionKind.feeling,
        ),
        suggestSupport: (r['suggestSupport'] as int? ?? 0) == 1,
        position: r['position'] as int? ?? 0,
        hidden: (r['hidden'] as int? ?? 0) == 1,
      );
}

class EmotionEntry {
  const EmotionEntry({
    required this.id,
    required this.localDateTime,
    required this.selectedLabel,
    this.optionalNote = '',
  });

  final String id;
  final String localDateTime;
  final String selectedLabel;
  final String optionalNote;

  Map<String, Object?> toRow() => {
        'id': id,
        'localDateTime': localDateTime,
        'selectedLabel': selectedLabel,
        'optionalNote': optionalNote,
      };

  factory EmotionEntry.fromRow(Map<String, Object?> r) => EmotionEntry(
        id: r['id'] as String,
        localDateTime: r['localDateTime'] as String,
        selectedLabel: r['selectedLabel'] as String,
        optionalNote: r['optionalNote'] as String? ?? '',
      );
}

// ---------------------------------------------------------------------------
// M4 – Câu chuyện xã hội
// ---------------------------------------------------------------------------

enum StorySource { ai, template, manual }

extension StorySourceLabel on StorySource {
  String get label {
    switch (this) {
      case StorySource.ai:
        return 'AI';
      case StorySource.template:
        return 'Mẫu cục bộ';
      case StorySource.manual:
        return 'Tự soạn';
    }
  }
}

enum StoryStatus { draft, approved, archived }

extension StoryStatusLabel on StoryStatus {
  String get label {
    switch (this) {
      case StoryStatus.draft:
        return 'Bản nháp';
      case StoryStatus.approved:
        return 'Đã duyệt';
      case StoryStatus.archived:
        return 'Lưu trữ';
    }
  }
}

class StoryStep {
  const StoryStep({
    required this.id,
    required this.storyId,
    required this.text,
    required this.iconKey,
    this.imageRef,
    required this.position,
  });

  final String id;
  final String storyId;
  final String text;
  final String iconKey;

  /// Ảnh thật do người chăm sóc thêm (phòng khám quen, ghế chờ…).
  final String? imageRef;
  final int position;

  StoryStep copyWith({
    String? storyId,
    String? text,
    String? iconKey,
    String? imageRef,
    bool clearImage = false,
    int? position,
  }) =>
      StoryStep(
        id: id,
        storyId: storyId ?? this.storyId,
        text: text ?? this.text,
        iconKey: iconKey ?? this.iconKey,
        imageRef: clearImage ? null : (imageRef ?? this.imageRef),
        position: position ?? this.position,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'storyId': storyId,
        'text': text,
        'iconKey': iconKey,
        'imageRef': imageRef,
        'position': position,
      };

  factory StoryStep.fromRow(Map<String, Object?> r) => StoryStep(
        id: r['id'] as String,
        storyId: r['storyId'] as String,
        text: r['text'] as String,
        iconKey: r['iconKey'] as String? ?? 'smile',
        imageRef: r['imageRef'] as String?,
        position: r['position'] as int? ?? 0,
      );
}

class SocialStory {
  const SocialStory({
    required this.id,
    required this.title,
    required this.source,
    required this.status,
    required this.updatedAt,
    this.approvedAt,
    this.caregiverTip = '',
    this.scenario = '',
    this.steps = const [],
    this.linkedCardIds = const [],
    this.isSample = false,
  });

  final String id;
  final String title;
  final StorySource source;
  final StoryStatus status;
  final String updatedAt;
  final String? approvedAt;

  /// CHỈ hiển thị trong khu vực người chăm sóc (Mục 6.6).
  final String caregiverTip;

  /// Mô tả gốc người chăm sóc đã nhập – giữ lại để thử lại khi lỗi.
  final String scenario;
  final List<StoryStep> steps;

  /// StoryCardLink: thẻ hỗ trợ liên kết (FR-M4-11).
  final List<String> linkedCardIds;
  final bool isSample;

  bool get visibleToChild => status == StoryStatus.approved; // BR-04

  SocialStory copyWith({
    String? title,
    StorySource? source,
    StoryStatus? status,
    String? updatedAt,
    String? approvedAt,
    bool clearApproved = false,
    String? caregiverTip,
    String? scenario,
    List<StoryStep>? steps,
    List<String>? linkedCardIds,
  }) =>
      SocialStory(
        id: id,
        title: title ?? this.title,
        source: source ?? this.source,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
        approvedAt: clearApproved ? null : (approvedAt ?? this.approvedAt),
        caregiverTip: caregiverTip ?? this.caregiverTip,
        scenario: scenario ?? this.scenario,
        steps: steps ?? this.steps,
        linkedCardIds: linkedCardIds ?? this.linkedCardIds,
        isSample: isSample,
      );

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'source': source.name,
        'status': status.name,
        'updatedAt': updatedAt,
        'approvedAt': approvedAt,
        'caregiverTip': caregiverTip,
        'scenario': scenario,
        'isSample': isSample ? 1 : 0,
      };

  factory SocialStory.fromRow(
    Map<String, Object?> r, {
    List<StoryStep> steps = const [],
    List<String> linkedCardIds = const [],
  }) =>
      SocialStory(
        id: r['id'] as String,
        title: r['title'] as String,
        source: StorySource.values.firstWhere(
          (s) => s.name == r['source'],
          orElse: () => StorySource.manual,
        ),
        status: StoryStatus.values.firstWhere(
          (s) => s.name == r['status'],
          orElse: () => StoryStatus.draft,
        ),
        updatedAt: r['updatedAt'] as String,
        approvedAt: r['approvedAt'] as String?,
        caregiverTip: r['caregiverTip'] as String? ?? '',
        scenario: r['scenario'] as String? ?? '',
        steps: steps,
        linkedCardIds: linkedCardIds,
        isSample: (r['isSample'] as int? ?? 0) == 1,
      );

  Map<String, dynamic> toExportJson() => {
        'id': id,
        'title': title,
        'source': source.name,
        'status': status.name,
        'updatedAt': updatedAt,
        'approvedAt': approvedAt,
        'steps': steps
            .map((s) => {'id': s.id, 'text': s.text, 'iconKey': s.iconKey})
            .toList(),
        'linkedCardIds': linkedCardIds,
      };
}
