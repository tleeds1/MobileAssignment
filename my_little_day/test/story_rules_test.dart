import 'package:flutter_test/flutter_test.dart';
import 'package:my_little_day/data/models.dart';
import 'package:my_little_day/domain/story_lifecycle.dart';
import 'package:my_little_day/domain/story_validator.dart';

Map<String, dynamic> validResponse() => {
      'title': 'Con sẽ đến phòng khám',
      'steps': [
        {'text': 'Con sẽ đến phòng khám cùng người chăm sóc.', 'icon': 'car'},
        {'text': 'Có thể có người nói chuyện và thiết bị.', 'icon': 'doctor'},
        {'text': 'Con có thể dùng thẻ nghỉ hoặc nhờ giúp đỡ.', 'icon': 'rest'},
        {'text': 'Khi xong, con sẽ rời phòng khám.', 'icon': 'done'},
      ],
      'caregiver_tip': 'Người chăm sóc cần điều chỉnh nội dung theo thực tế.',
      'requires_review': true,
      'source': 'ai',
    };

void main() {
  group('StoryValidator – đầu vào (Mục 6.6)', () {
    test('mô tả 8–240 ký tự', () {
      expect(
          StoryValidator.validateRequest(
              scenario: 'ngắn', language: 'vi', sensoryPreferences: []),
          isNotEmpty);
      expect(
          StoryValidator.validateRequest(
              scenario: 'x' * 241, language: 'vi', sensoryPreferences: []),
          isNotEmpty);
      expect(
          StoryValidator.validateRequest(
              scenario: 'Con sẽ đi khám cùng mẹ.',
              language: 'vi',
              sensoryPreferences: []),
          isEmpty);
    });

    test('ngôn ngữ chỉ vi/en; tối đa 5 lưu ý, mỗi lưu ý ≤ 80 ký tự', () {
      expect(
          StoryValidator.validateRequest(
              scenario: 'Con sẽ đi khám.', language: 'fr', sensoryPreferences: []),
          isNotEmpty);
      expect(
          StoryValidator.validateRequest(
              scenario: 'Con sẽ đi khám.',
              language: 'vi',
              sensoryPreferences: List.filled(6, 'a')),
          isNotEmpty);
      expect(
          StoryValidator.validateRequest(
              scenario: 'Con sẽ đi khám.',
              language: 'vi',
              sensoryPreferences: ['a' * 81]),
          isNotEmpty);
    });

    test('cảnh báo dữ liệu nhận diện', () {
      expect(StoryValidator.privacyWarnings('Gọi 0901234567'), isNotEmpty);
      expect(StoryValidator.privacyWarnings('Nhà ở phường 5, quận 3'),
          isNotEmpty);
      expect(StoryValidator.privacyWarnings('Con sẽ đi khám tai'), isEmpty);
    });
  });

  group('StoryValidator – đầu ra (TC-13, TC-14)', () {
    test('phản hồi hợp lệ', () {
      final d = StoryValidator.parseResponse(validResponse());
      expect(d.steps.length, 4);
      expect(d.source, 'ai');
    });

    test('icon ngoài danh sách cho phép bị từ chối', () {
      final r = validResponse();
      (r['steps'] as List)[0] = {'text': 'Con đi xe.', 'icon': 'rocket'};
      expect(() => StoryValidator.parseResponse(r),
          throwsA(isA<ValidationError>()));
    });

    test('số bước ngoài 4–6 bị từ chối', () {
      final r = validResponse();
      r['steps'] = (r['steps'] as List).take(3).toList();
      expect(() => StoryValidator.parseResponse(r),
          throwsA(isA<ValidationError>()));
    });

    test('thiếu requires_review hoặc sai kiểu bị từ chối', () {
      final r = validResponse()..['requires_review'] = false;
      expect(() => StoryValidator.parseResponse(r),
          throwsA(isA<ValidationError>()));
      expect(() => StoryValidator.parseResponse('không phải JSON object'),
          throwsA(isA<ValidationError>()));
    });

    test('nội dung áp đặt / y khoa bị từ chối', () {
      final r = validResponse();
      (r['steps'] as List)[1] = {
        'text': 'Con phải ngồi yên và không được khóc.',
        'icon': 'person'
      };
      expect(() => StoryValidator.parseResponse(r),
          throwsA(isA<ValidationError>()));
    });

    test('so khớp theo ranh giới từ ("hư" không khớp "những")', () {
      expect(StoryValidator.findForbidden('Có những người ở đó.'), isEmpty);
      expect(StoryValidator.findForbidden('Con là đứa trẻ hư.'), isNotEmpty);
    });

    test('cảnh báo câu dài hơn 15 từ', () {
      expect(
          StoryValidator.stepWarnings(
              'Con sẽ đi đến phòng khám cùng với mẹ và ba vào buổi sáng sớm hôm nay nhé'),
          isNotEmpty);
      expect(StoryValidator.stepWarnings('Con ngồi chờ.'), isEmpty);
    });
  });

  group('StoryLifecycle (BR-04, BR-05)', () {
    var n = 0;
    String id() => 'id${n++}';

    SocialStory draft() => StoryLifecycle.fromDraft(
          id: 's1',
          draft: StoryValidator.parseResponse(validResponse()),
          scenario: 'Con sẽ đi khám.',
          newStepId: id,
        );

    test('bản nháp AI luôn ở trạng thái draft và không hiển thị cho trẻ', () {
      final s = draft();
      expect(s.status, StoryStatus.draft);
      expect(s.source, StorySource.ai);
      expect(s.visibleToChild, isFalse);
    });

    test('duyệt → hiển thị cho trẻ, có thời điểm duyệt (TC-17)', () {
      final a = StoryLifecycle.approve(draft());
      expect(a.status, StoryStatus.approved);
      expect(a.approvedAt, isNotNull);
      expect(a.visibleToChild, isTrue);
    });

    test('sửa nội dung câu chuyện đã duyệt → về bản nháp (TC-18)', () {
      final a = StoryLifecycle.approve(draft());
      final edited = a.copyWith(title: 'Tiêu đề mới');
      final next = StoryLifecycle.applyEdit(a, edited);
      expect(next.status, StoryStatus.draft);
      expect(next.approvedAt, isNull);
    });

    test('đổi liên kết thẻ KHÔNG làm mất hiệu lực duyệt (FR-M4-11)', () {
      final a = StoryLifecycle.approve(draft());
      final next =
          StoryLifecycle.applyEdit(a, a.copyWith(linkedCardIds: ['card-1']));
      expect(next.status, StoryStatus.approved);
    });

    test('không duyệt được câu chuyện thiếu nội dung', () {
      final s = draft().copyWith(title: '');
      expect(() => StoryLifecycle.approve(s), throwsA(isA<StoryRuleError>()));
    });

    test('lưu trữ → ẩn với trẻ; khôi phục → bản nháp', () {
      final a = StoryLifecycle.archive(StoryLifecycle.approve(draft()));
      expect(a.visibleToChild, isFalse);
      expect(StoryLifecycle.restore(a).status, StoryStatus.draft);
    });
  });
}
