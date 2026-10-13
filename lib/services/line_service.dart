import '../di/service_locator.dart';
import 'api_service.dart';

class LineService {
  LineService._();

  static final LineService I = LineService._();

  ApiService get _api => sl<ApiService>();

  /// 取得 LINE Login authorization URL。
  Future<String> getLoginUrl() async {
    final response = await _api.dio.get(
      '/api/line/login-url',
    );

    final data =
        response.data as Map<String, dynamic>? ?? {};

    final url =
        data['authorization_url'] as String?;

    if (url == null || url.isEmpty) {
      throw Exception(
        'Backend did not return LINE authorization URL.',
      );
    }

    return url;
  }

  Future<bool> getBindingStatus() async {
    final response = await _api.dio.get(
      '/api/line/status',
    );

    final raw = response.data;

    if (raw is! Map) {
      throw Exception(
        'Unexpected LINE status response: $raw',
      );
    }

    final data = Map<String, dynamic>.from(raw);

    return data['bound'] as bool? ?? false;
  }

  Future<String> sendTestMessage({
    String? text,
  }) async {
    final response = await _api.dio.post(
      '/api/line/send-test',
      data: {
        if (text != null && text.isNotEmpty)
          'text': text,
      },
    );

    final data =
        response.data as Map<String, dynamic>? ?? {};

    if (data['success'] != true) {
      throw Exception(
        'LINE message was not sent successfully.',
      );
    }

    return data['message'] as String? ??
        'Message sent.';
  }
}