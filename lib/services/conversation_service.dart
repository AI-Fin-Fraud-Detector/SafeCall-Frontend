import 'package:dio/dio.dart';

import '../config/api_config.dart';
import '../models/conversation_models.dart';
import '../di/service_locator.dart';
import 'api_service.dart';

class ConversationService {
  Dio get _dio => sl<ApiService>().dio;

  /// GET /api/fraud/conversations — before: cursor, limit: max results
  Future<List<Conversation>> getConversations({
    String? before,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;

    final resp = await _dio.get(
      ApiConfig.conversationsPath,
      queryParameters: params,
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to load conversations (${resp.statusCode})');
    }

    final List<dynamic> list =
        (resp.data as Map<String, dynamic>)['conversations'] as List<dynamic>;
    return list
        .map((e) => Conversation.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// GET /api/fraud/conversations/[id]/messages — before: cursor, limit: max results
  Future<List<ConversationMessage>> getMessages(
    String conversationId, {
    String? before,
    int limit = 50,
  }) async {
    final params = <String, dynamic>{'limit': limit};
    if (before != null) params['before'] = before;

    final resp = await _dio.get(
      '${ApiConfig.conversationsPath}/$conversationId/messages',
      queryParameters: params,
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to load messages (${resp.statusCode})');
    }

    final List<dynamic> list =
        (resp.data as Map<String, dynamic>)['messages'] as List<dynamic>;
    return list
        .map((e) =>
            ConversationMessage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}
