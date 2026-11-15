import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/story_validator.dart';

enum StoryApiErrorKind {
  notConfigured,
  invalidInput, // 400
  tooLarge, // 413
  rateLimited, // 429
  server, // 500
  unavailable, // 502/503
  timeout, // 504 hoặc hết thời gian phía ứng dụng
  offline,
  invalidOutput, // phản hồi sai lược đồ / nội dung không phù hợp
}

class StoryApiException implements Exception {
  StoryApiException(this.kind, {this.requestId, this.retryAfter, this.details});

  final StoryApiErrorKind kind;
  final String? requestId;
  final Duration? retryAfter;
  final List<String>? details;

  /// Thông báo dễ hiểu, trung tính (Bảng 18) – không lộ chi tiết kỹ thuật.
  String get message {
    switch (kind) {
      case StoryApiErrorKind.notConfigured:
        return 'Chưa cấu hình máy chủ AI. Bạn có thể dùng mẫu cục bộ hoặc tự soạn.';
      case StoryApiErrorKind.invalidInput:
        return 'Mô tả chưa hợp lệ. Hãy chỉnh lại nội dung đã nhập.';
      case StoryApiErrorKind.tooLarge:
        return 'Mô tả quá dài. Hãy rút ngắn rồi thử lại.';
      case StoryApiErrorKind.rateLimited:
        final s = retryAfter?.inSeconds;
        return s != null
            ? 'Đã gửi quá nhiều yêu cầu. Có thể thử lại sau khoảng $s giây.'
            : 'Đã gửi quá nhiều yêu cầu. Vui lòng thử lại sau ít phút.';
      case StoryApiErrorKind.server:
        return 'Máy chủ gặp lỗi${requestId != null ? ' (mã yêu cầu: $requestId)' : ''}. '
            'Bạn có thể dùng mẫu cục bộ hoặc tự soạn.';
      case StoryApiErrorKind.unavailable:
        return 'Dịch vụ AI tạm thời không sẵn sàng. Nội dung đã nhập được giữ lại.';
      case StoryApiErrorKind.timeout:
        return 'Hết thời gian chờ. Nội dung đã nhập được giữ lại – bạn có thể thử lại hoặc dùng mẫu.';
      case StoryApiErrorKind.offline:
        return 'Không có kết nối mạng. Bạn vẫn có thể dùng mẫu cục bộ hoặc tự soạn.';
      case StoryApiErrorKind.invalidOutput:
        return 'Bản nháp nhận được không đạt kiểm tra an toàn nên đã bị từ chối. '
            'Hãy dùng mẫu cục bộ hoặc tự soạn.';
    }
  }

  @override
  String toString() => 'StoryApiException($kind)';
}

/// Client cho POST /api/v1/stories/generate (Mục 6.6).
/// Khóa của nhà cung cấp AI KHÔNG nằm trong ứng dụng – chỉ ở máy chủ.
class StoryApiClient {
  StoryApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.appVersion = '1.0.0',
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final Duration timeout;
  final String appVersion;
  final http.Client _client;

  Future<StoryDraft> generate({
    required String scenario,
    String language = 'vi',
    List<String> sensoryPreferences = const [],
  }) async {
    if (baseUrl.trim().isEmpty) {
      throw StoryApiException(StoryApiErrorKind.notConfigured);
    }
    final problems = StoryValidator.validateRequest(
      scenario: scenario,
      language: language,
      sensoryPreferences: sensoryPreferences,
    );
    if (problems.isNotEmpty) {
      throw StoryApiException(StoryApiErrorKind.invalidInput,
          details: problems);
    }

    final uri = Uri.parse(baseUrl.trim()).resolve('/api/v1/stories/generate');
    http.Response res;
    try {
      res = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'X-App-Version': appVersion,
            },
            body: jsonEncode({
              'scenario': scenario.trim(),
              'language': language,
              'sensory_preferences':
                  sensoryPreferences.map((e) => e.trim()).toList(),
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw StoryApiException(StoryApiErrorKind.timeout);
    } on SocketException {
      throw StoryApiException(StoryApiErrorKind.offline);
    } on http.ClientException {
      throw StoryApiException(StoryApiErrorKind.offline);
    }

    final requestId = res.headers['x-request-id'];
    switch (res.statusCode) {
      case 200:
        break;
      case 400:
        throw StoryApiException(StoryApiErrorKind.invalidInput,
            requestId: requestId);
      case 413:
        throw StoryApiException(StoryApiErrorKind.tooLarge,
            requestId: requestId);
      case 429:
        final ra = int.tryParse(res.headers['retry-after'] ?? '');
        throw StoryApiException(StoryApiErrorKind.rateLimited,
            requestId: requestId,
            retryAfter: ra != null ? Duration(seconds: ra) : null);
      case 502:
      case 503:
        throw StoryApiException(StoryApiErrorKind.unavailable,
            requestId: requestId);
      case 504:
        throw StoryApiException(StoryApiErrorKind.timeout,
            requestId: requestId);
      default:
        throw StoryApiException(StoryApiErrorKind.server,
            requestId: requestId);
    }

    Object? json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw StoryApiException(StoryApiErrorKind.invalidOutput,
          requestId: requestId);
    }
    try {
      // Ứng dụng xác thực lại dù máy chủ đã kiểm tra (Mục 7.5).
      return StoryValidator.parseResponse(json);
    } on ValidationError catch (e) {
      throw StoryApiException(StoryApiErrorKind.invalidOutput,
          requestId: requestId, details: e.problems);
    }
  }
}
