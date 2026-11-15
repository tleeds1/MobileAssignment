import '../domain/story_validator.dart';

/// Mẫu câu chuyện cục bộ – hoạt động hoàn toàn ngoại tuyến (FR-M4-07, BR-06).
/// Mỗi bước là một câu đơn ngắn, dùng cách nói "có thể", "nếu con muốn".
class LocalStoryTemplate {
  const LocalStoryTemplate({
    required this.id,
    required this.name,
    required this.keywords,
    required this.title,
    required this.steps,
  });

  final String id;
  final String name;
  final List<String> keywords;
  final String title;
  final List<DraftStep> steps;

  StoryDraft toDraft() => StoryDraft(
        title: title,
        steps: steps,
        caregiverTip:
            'Mẫu cục bộ – hãy chỉnh từng bước và thay hình bằng ảnh thật nếu có.',
        source: 'template',
      );
}

class LocalStoryTemplates {
  LocalStoryTemplates._();

  static const all = <LocalStoryTemplate>[
    LocalStoryTemplate(
      id: 'doctor',
      name: 'Đi khám bệnh',
      keywords: ['khám', 'bác sĩ', 'bệnh viện', 'phòng khám', 'tiêm'],
      title: 'Con đi khám',
      steps: [
        DraftStep('Con đi xe đến phòng khám.', 'car'),
        DraftStep('Con ngồi chờ cùng người lớn.', 'clock'),
        DraftStep('Bác sĩ có thể nói chuyện với con.', 'doctor'),
        DraftStep('Nếu cần, con có thể chọn thẻ nghỉ.', 'rest'),
        DraftStep('Xong rồi, con về nhà.', 'home'),
      ],
    ),
    LocalStoryTemplate(
      id: 'haircut',
      name: 'Đi cắt tóc',
      keywords: ['cắt tóc', 'tiệm tóc', 'hớt tóc'],
      title: 'Con đi cắt tóc',
      steps: [
        DraftStep('Con đến tiệm cắt tóc cùng người lớn.', 'car'),
        DraftStep('Con ngồi lên ghế.', 'person'),
        DraftStep('Có thể có tiếng kéo gần tai.', 'scissors'),
        DraftStep('Con có thể xin nghỉ một chút.', 'rest'),
        DraftStep('Xong rồi, con về nhà.', 'done'),
      ],
    ),
    LocalStoryTemplate(
      id: 'library',
      name: 'Đến thư viện',
      keywords: ['thư viện', 'sách'],
      title: 'Con đến thư viện',
      steps: [
        DraftStep('Con đến thư viện cùng người lớn.', 'parent'),
        DraftStep('Ở đó có sách và nhiều người.', 'book'),
        DraftStep('Nếu cần, con có thể chọn thẻ nghỉ.', 'rest'),
        DraftStep('Sau đó, con về nhà cùng người lớn.', 'home'),
      ],
    ),
    LocalStoryTemplate(
      id: 'dentist',
      name: 'Đi nha sĩ',
      keywords: ['nha sĩ', 'răng', 'nha khoa'],
      title: 'Con đi nha sĩ',
      steps: [
        DraftStep('Con đến phòng nha cùng người lớn.', 'car'),
        DraftStep('Con có thể nằm trên một chiếc ghế lớn.', 'person'),
        DraftStep('Nha sĩ có thể nhìn răng của con.', 'doctor'),
        DraftStep('Con có thể giơ tay để xin dừng.', 'rest'),
        DraftStep('Xong rồi, con về nhà.', 'home'),
      ],
    ),
    LocalStoryTemplate(
      id: 'school',
      name: 'Lớp học mới',
      keywords: ['trường', 'lớp', 'cô giáo', 'thầy giáo'],
      title: 'Con đến lớp mới',
      steps: [
        DraftStep('Con đến trường cùng người lớn.', 'school'),
        DraftStep('Ở lớp có thể có cô giáo và các bạn.', 'person'),
        DraftStep('Có thể có tiếng chuông.', 'ear'),
        DraftStep('Con có thể nhờ cô giúp đỡ.', 'smile'),
        DraftStep('Hết giờ, người lớn đón con về.', 'home'),
      ],
    ),
    LocalStoryTemplate(
      id: 'generic',
      name: 'Sự kiện chung',
      keywords: [],
      title: 'Một việc mới hôm nay',
      steps: [
        DraftStep('Hôm nay con có một việc mới.', 'clock'),
        DraftStep('Con đi cùng người lớn.', 'parent'),
        DraftStep('Ở đó có thể có nhiều người.', 'person'),
        DraftStep('Nếu cần, con có thể chọn thẻ nghỉ.', 'rest'),
        DraftStep('Xong rồi, con về nhà.', 'home'),
      ],
    ),
  ];

  /// Gợi ý mẫu phù hợp nhất với mô tả; luôn trả về một mẫu.
  static LocalStoryTemplate suggest(String scenario) {
    final s = scenario.toLowerCase();
    for (final t in all) {
      if (t.keywords.any(s.contains)) return t;
    }
    return all.last;
  }
}
