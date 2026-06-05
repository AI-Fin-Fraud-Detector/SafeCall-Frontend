import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

class SSEService {
  SSEService._();
  static final SSEService I = SSEService._();

  final _eventCtrl = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _eventCtrl.stream;

  String? _userId;
  String? _app;
  String? _token;
  String? _baseUrl;
  http.StreamedResponse? _response;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  Future<void> connect({
    required String userId,
    required String app,
    required String token,
    required String baseUrl,
  }) async {
    if (_isConnected && _userId == userId && _app == app) {
      debugPrint('[SSE] Already connected');
      return;
    }

    _userId = userId;
    _app = app;
    _token = token;
    _baseUrl = baseUrl;

    await _connect();
  }

  Future<void> _connect() async {
    final userId = _userId;
    final app = _app;
    final token = _token;
    final baseUrl = _baseUrl;

    if (userId == null || app == null || token == null || baseUrl == null) {
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/push/events/$app');
      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['X-User-Id'] = userId;

      _response = await http.Client().send(request);

      if (_response!.statusCode == 200) {
        _isConnected = true;
        debugPrint('[SSE] Connected: $userId ($app)');
        _listenToStream();
      } else {
        debugPrint('[SSE] Connection failed: ${_response!.statusCode}');
        _scheduleReconnect();
      }
    } catch (e) {
      debugPrint('[SSE] Connection error: $e');
      _scheduleReconnect();
    }
  }

  void _listenToStream() {
    _response!.stream.transform(utf8.decoder).transform(LineSplitter()).listen(
      (line) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            _eventCtrl.add(json);
            debugPrint('[SSE] Event received: $json');
          } catch (e) {
            debugPrint('[SSE] Failed to parse event: $e');
          }
        } else if (line.startsWith(':')) {
          debugPrint('[SSE] Heartbeat');
        }
      },
      onError: (e) {
        debugPrint('[SSE] Stream error: $e');
        _isConnected = false;
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[SSE] Stream closed');
        _isConnected = false;
        _scheduleReconnect();
      },
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, _connect);
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _response?.stream.drain();
    _isConnected = false;
    debugPrint('[SSE] Disconnected');
  }

  void dispose() {
    disconnect();
    _eventCtrl.close();
  }
}
