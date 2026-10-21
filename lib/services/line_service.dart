import 'package:dio/dio.dart';

import '../di/service_locator.dart';
import 'api_service.dart';

class LineService {
  LineService._();

  static final LineService I = LineService._();

  ApiService get _api => sl<ApiService>();

  /// The shared Dio client accepts every status below 500, so a 4xx response
  /// does not throw. Reject non-2xx and non-object bodies here so an error
  /// payload can never be read as login data or as "not bound".
  Map<String, dynamic> _requireJsonMap(
    Response<dynamic> response,
    String what,
  ) {
    final status = response.statusCode;

    if (status == null || status < 200 || status >= 300) {
      throw Exception(
        '$what failed (HTTP ${status ?? 'unknown'}): ${response.data}',
      );
    }

    final raw = response.data;

    if (raw is! Map) {
      throw Exception('Unexpected $what response: $raw');
    }

    return Map<String, dynamic>.from(raw);
  }

  /// 取得 LINE Login authorization URL。
  Future<String> getLoginUrl() async {
    final response = await _api.dio.get(
      '/api/notify/line/login-url',
    );

    final data = _requireJsonMap(response, 'LINE login URL request');

    final url = data['authorization_url'];

    if (url is! String || url.isEmpty) {
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

    final data = _requireJsonMap(response, 'LINE status request');

    final bound = data['bound'];

    if (bound is! bool) {
      throw Exception('Unexpected LINE status response: $data');
    }

    return bound;
  }

  /// 解除 LINE 綁定。
  Future<void> unbind() async {
    final response = await _api.dio.delete(
      '/api/notify/line/binding',
    );

    _requireJsonMap(response, 'LINE unbind request');
  }
}
