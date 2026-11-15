import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:my_little_day/services/story_api_client.dart';

const okBody = {
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

StoryApiClient client(MockClientHandler h,
        {Duration timeout = const Duration(seconds: 15)}) =>
    StoryApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(h),
        timeout: timeout);

Future<StoryApiErrorKind> kindOf(Future<Object?> f) async {
  try {
    await f;
  } on StoryApiException catch (e) {
    return e.kind;
  }
  fail('expected StoryApiException');
}

void main() {
  test('200 hợp lệ → bản nháp; gọi đúng endpoint /api/v1/stories/generate',
      () async {
    late http.Request captured;
    final c = client((req) async {
      captured = req;
      return http.Response.bytes(utf8.encode(jsonEncode(okBody)), 200,
          headers: {'content-type': 'application/json'});
    });
    final d = await c.generate(scenario: 'Con sẽ đi khám cùng mẹ.');
    expect(d.steps.length, 4);
    expect(captured.url.path, '/api/v1/stories/generate');
    final body = jsonDecode(captured.body) as Map;
    expect(body['language'], 'vi');
    expect(body.containsKey('sensory_preferences'), isTrue);
  });

  test('không cấu hình máy chủ → notConfigured (không gọi mạng)', () async {
    final c = StoryApiClient(baseUrl: '');
    expect(await kindOf(c.generate(scenario: 'Con sẽ đi khám.')),
        StoryApiErrorKind.notConfigured);
  });

  test('đầu vào sai bị chặn phía ứng dụng (TC-12)', () async {
    final c = client((_) async => http.Response('', 200));
    expect(await kindOf(c.generate(scenario: 'ngắn')),
        StoryApiErrorKind.invalidInput);
  });

  test('ánh xạ mã HTTP theo Bảng 18', () async {
    Future<StoryApiErrorKind> code(int status,
            [Map<String, String> h = const {}]) =>
        kindOf(client((_) async => http.Response('{}', status, headers: h))
            .generate(scenario: 'Con sẽ đi khám cùng mẹ.'));

    expect(await code(400), StoryApiErrorKind.invalidInput);
    expect(await code(413), StoryApiErrorKind.tooLarge);
    expect(await code(429), StoryApiErrorKind.rateLimited);
    expect(await code(500), StoryApiErrorKind.server);
    expect(await code(502), StoryApiErrorKind.unavailable);
    expect(await code(503), StoryApiErrorKind.unavailable);
    expect(await code(504), StoryApiErrorKind.timeout);
  });

  test('429 đọc Retry-After', () async {
    try {
      await client((_) async =>
              http.Response('{}', 429, headers: {'retry-after': '30'}))
          .generate(scenario: 'Con sẽ đi khám cùng mẹ.');
      fail('should throw');
    } on StoryApiException catch (e) {
      expect(e.retryAfter, const Duration(seconds: 30));
      expect(e.message, contains('30'));
    }
  });

  test('hết thời gian phía ứng dụng → timeout (TC-15)', () async {
    final c = client(
      (_) => Completer<http.Response>().future, // không bao giờ trả lời
      timeout: const Duration(milliseconds: 50),
    );
    expect(await kindOf(c.generate(scenario: 'Con sẽ đi khám cùng mẹ.')),
        StoryApiErrorKind.timeout);
  });

  test('200 nhưng sai lược đồ / icon lạ → invalidOutput, không công bố (TC-14)',
      () async {
    final bad = jsonDecode(jsonEncode(okBody)) as Map<String, dynamic>;
    (bad['steps'] as List)[0] = {'text': 'Con đi xe.', 'icon': 'rocket'};
    final c = client((_) async =>
        http.Response.bytes(utf8.encode(jsonEncode(bad)), 200));
    expect(await kindOf(c.generate(scenario: 'Con sẽ đi khám cùng mẹ.')),
        StoryApiErrorKind.invalidOutput);

    final notJson = client((_) async => http.Response('<html>', 200));
    expect(await kindOf(notJson.generate(scenario: 'Con sẽ đi khám cùng mẹ.')),
        StoryApiErrorKind.invalidOutput);
  });
}
