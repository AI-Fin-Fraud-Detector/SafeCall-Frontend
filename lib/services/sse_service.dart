import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'debug_logger.dart';

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
    final msg = '[SSE] connect() called: userId=$userId app=$app';
    debugPrint(msg);
    DebugLogger.I.log(msg);

    // If already connected to same user/app, reuse connection
    if (_isConnected && _userId == userId && _app == app) {
      debugPrint('[SSE] Already connected to $userId ($app)');
      DebugLogger.I.log('[SSE] Already connected, reusing...');
      return;
    }

    // If connected to different user, disconnect first
    if (_isConnected && (_userId != userId || _app != app)) {
      debugPrint('[SSE] Disconnecting from $_userId ($_app) to connect to $userId ($app)');
      DebugLogger.I.log('[SSE] Disconnecting previous connection');
      disconnect();
    }

    _userId = userId;
    _app = app;
    _token = token;
    _baseUrl = baseUrl;

    debugPrint('[SSE] Parameters set, calling _connect()...');
    DebugLogger.I.log('[SSE] Initiating connection...');
    await _connect();
  }

  Future<void> _connect() async {
    final userId = _userId;
    final app = _app;
    final token = _token;
    final baseUrl = _baseUrl;

    if (userId == null || app == null || token == null || baseUrl == null) {
      final msg = '[SSE] Missing params: userId=$userId app=$app token=$token baseUrl=$baseUrl';
      debugPrint(msg);
      DebugLogger.I.log(msg);
      return;
    }

    try {
      final uri = Uri.parse('$baseUrl/api/push/events/$app');
      debugPrint('[SSE] Connecting to: $uri');
      DebugLogger.I.log('[SSE] Connecting to: $baseUrl/api/push/events/$app');

      final request = http.Request('GET', uri)
        ..headers['Authorization'] = 'Bearer $token'
        ..headers['X-User-Id'] = userId;

      debugPrint('[SSE] Sending request...');
      DebugLogger.I.log('[SSE] Sending request with auth headers');

      _response = await http.Client().send(request);

      debugPrint('[SSE] Got response: ${_response!.statusCode}');
      DebugLogger.I.log('[SSE] Got response: statusCode=${_response!.statusCode}');

      if (_response!.statusCode == 200) {
        _isConnected = true;
        debugPrint('[SSE] ✓ Connected: $userId ($app)');
        DebugLogger.I.log('[SSE] ✓ Connected successfully, starting to listen...');
        _listenToStream();
      } else {
        debugPrint('[SSE] ✗ Connection failed: ${_response!.statusCode}');
        DebugLogger.I.log('[SSE] ✗ HTTP ${_response!.statusCode} - will reconnect in 3s');
        _isConnected = false;
        _scheduleReconnect();
      }
    } catch (e, st) {
      final msg = '[SSE] ✗ Exception: $e';
      debugPrint(msg);
      debugPrint('Stack: $st');
      DebugLogger.I.log(msg);
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _listenToStream() {
    debugPrint('[SSE] Starting to listen to stream...');
    DebugLogger.I.log('[SSE] Stream listener attached, waiting for events...');

    _response!.stream.transform(utf8.decoder).transform(LineSplitter()).listen(
      (line) {
        if (line.isEmpty) {
          return;
        }

        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final eventType = json['type'] ?? 'unknown';
            debugPrint('[SSE] ✓ Parsed JSON: $eventType');
            DebugLogger.I.log('[SSE] ✓ Event received: $eventType');
            _eventCtrl.add(json);
            debugPrint('[SSE] ✓ Event emitted to stream');
          } catch (e) {
            debugPrint('[SSE] ✗ Failed to parse event: $e');
            DebugLogger.I.log('[SSE] ✗ Parse error: $e');
          }
        } else if (line.startsWith(':')) {
          debugPrint('[SSE] ❤ Heartbeat');
        }
      },
      onError: (e) {
        debugPrint('[SSE] ✗ Stream error: $e');
        DebugLogger.I.log('[SSE] ✗ Stream error: $e');
        _isConnected = false;
        _scheduleReconnect();
      },
      onDone: () {
        debugPrint('[SSE] ⊗ Stream closed');
        DebugLogger.I.log('[SSE] ⊗ Stream closed, will reconnect');
        _isConnected = false;
        _scheduleReconnect();
      },
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    debugPrint('[SSE] Scheduling reconnect in ${_reconnectDelay.inSeconds}s...');
    DebugLogger.I.log('[SSE] Will retry in ${_reconnectDelay.inSeconds}s');
    _reconnectTimer = Timer(_reconnectDelay, () {
      debugPrint('[SSE] Reconnect timer fired, attempting to connect...');
      DebugLogger.I.log('[SSE] Reconnect timer fired');
      _connect();
    });
  }

  void disconnect() {
    debugPrint('[SSE] Disconnecting from $_userId ($_app)...');
    _reconnectTimer?.cancel();
    _response?.stream.drain();
    _isConnected = false;
    _response = null;
    debugPrint('[SSE] ✓ Disconnected and cleaned up');
  }

  void dispose() {
    disconnect();
    _eventCtrl.close();
  }
}
