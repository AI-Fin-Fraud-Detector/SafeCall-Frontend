import '../di/service_locator.dart';
import 'api_service.dart';

class LineService {
  LineService._();

  static final LineService I = LineService._();

  ApiService get _api => sl<ApiService>();

  /// 取得 LINE Login authorization URL。
  Future<String> getLoginUrl() async {
    final response = await _api.dio.get(
      '/api/notify/line/login-url',
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
      '/api/notify/line/status',
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
}
