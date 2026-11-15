import '../core/date_utils.dart';
import '../data/models.dart';
import 'story_validator.dart';

class StoryRuleError implements Exception {
  StoryRuleError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Vòng đời nội dung chuẩn bị sự kiện (Hình 3, BR-04, BR-05, FR-M4-05/06).
///
/// draft --(duyệt)--> approved --(sửa nội dung)--> draft
///   \                    \--(lưu trữ)--> archived
///    \--(xóa)
///
/// AI/mẫu chỉ tạo bản nháp; chỉ thao tác của người chăm sóc mới duyệt.
class StoryLifecycle {
  StoryLifecycle._();

  static const minSteps = 1;
  static const maxSteps = 8;

  static SocialStory fromDraft({
    required String id,
    required StoryDraft draft,
    required String scenario,
    required String Function() newStepId,
  }) {
    final now = LocalDate.isoNow();
    return SocialStory(
      id: id,
      title: draft.title,
      source: draft.source == 'ai' ? StorySource.ai : StorySource.template,
      status: StoryStatus.draft, // không bao giờ tự duyệt
      updatedAt: now,
      caregiverTip: draft.caregiverTip,
      scenario: scenario,
      steps: [
        for (var i = 0; i < draft.steps.length; i++)
          StoryStep(
            id: newStepId(),
            storyId: id,
            text: draft.steps[i].text,
            iconKey: draft.steps[i].icon,
            position: i,
          ),
      ],
    );
  }

  static bool _contentEquals(SocialStory a, SocialStory b) {
    if (a.title != b.title || a.steps.length != b.steps.length) return false;
    for (var i = 0; i < a.steps.length; i++) {
      final x = a.steps[i], y = b.steps[i];
      if (x.text != y.text || x.iconKey != y.iconKey || x.imageRef != y.imageRef) {
        return false;
      }
    }
    return true;
  }

  /// Áp dụng chỉnh sửa. Nếu câu chuyện đã duyệt bị đổi nội dung → quay về
  /// bản nháp và mất hiệu lực duyệt (BR-05). Liên kết thẻ không tính là
  /// thay đổi nội dung (FR-M4-11).
  static SocialStory applyEdit(SocialStory original, SocialStory edited) {
    final changed = !_contentEquals(original, edited);
    final now = LocalDate.isoNow();
    if (!changed) {
      return edited.copyWith(
        status: original.status,
        approvedAt: original.approvedAt,
        updatedAt: now,
      );
    }
    if (original.status == StoryStatus.approved) {
      return edited.copyWith(
        status: StoryStatus.draft,
        clearApproved: true,
        updatedAt: now,
      );
    }
    return edited.copyWith(status: original.status, updatedAt: now);
  }

  static List<String> approvalProblems(SocialStory s) {
    final p = <String>[];
    if (s.title.trim().isEmpty) p.add('Cần có tiêu đề.');
    if (s.steps.length < minSteps || s.steps.length > maxSteps) {
      p.add('Câu chuyện cần $minSteps–$maxSteps bước.');
    }
    if (s.steps.any((st) => st.text.trim().isEmpty)) {
      p.add('Mỗi bước cần có nội dung.');
    }
    final bad = [s.title, ...s.steps.map((e) => e.text)]
        .expand(StoryValidator.findForbidden)
        .toSet();
    if (bad.isNotEmpty) {
      p.add('Có cụm từ áp đặt/y khoa: ${bad.join(', ')}');
    }
    return p;
  }

  /// "Duyệt và cho trẻ xem" – thao tác riêng của người chăm sóc.
  static SocialStory approve(SocialStory s) {
    final problems = approvalProblems(s);
    if (problems.isNotEmpty) throw StoryRuleError(problems.join(' '));
    if (s.status == StoryStatus.archived) {
      throw StoryRuleError('Câu chuyện đã lưu trữ – hãy khôi phục trước.');
    }
    final now = LocalDate.isoNow();
    return s.copyWith(
        status: StoryStatus.approved, approvedAt: now, updatedAt: now);
  }

  static SocialStory archive(SocialStory s) => s.copyWith(
      status: StoryStatus.archived,
      clearApproved: true,
      updatedAt: LocalDate.isoNow());

  /// Khôi phục từ lưu trữ về bản nháp (cần duyệt lại).
  static SocialStory restore(SocialStory s) => s.copyWith(
      status: StoryStatus.draft,
      clearApproved: true,
      updatedAt: LocalDate.isoNow());
}
