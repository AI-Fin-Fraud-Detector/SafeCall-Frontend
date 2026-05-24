class ConversationMetadata {
  final String? callerPhoneNumber;
  final String? callerName;

  const ConversationMetadata({this.callerPhoneNumber, this.callerName});

  factory ConversationMetadata.fromJson(Map<String, dynamic> json) =>
      ConversationMetadata(
        callerPhoneNumber: json['caller_phone_number'] as String?,
        callerName: json['caller_name'] as String?,
      );
}

class Conversation {
  final String id;
  final String? title;
  final ConversationMetadata? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Conversation({
    required this.id,
    this.title,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['conversation_id'] as String,
        title: json['title'] as String?,
        metadata: json['metadata'] != null
            ? ConversationMetadata.fromJson(
                Map<String, dynamic>.from(json['metadata'] as Map))
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class ConversationMessage {
  final String id;
  final String role;
  final String content;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const ConversationMessage({
    required this.id,
    required this.role,
    required this.content,
    this.metadata,
    required this.createdAt,
  });

  factory ConversationMessage.fromJson(Map<String, dynamic> json) =>
      ConversationMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String,
        metadata: json['metadata'] != null
            ? Map<String, dynamic>.from(json['metadata'] as Map)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
