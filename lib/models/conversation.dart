import 'chat_message.dart';

class Conversation {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime modifiedAt;
  String modelUsed;
  String? systemPrompt;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.title,
    DateTime? createdAt,
    DateTime? modifiedAt,
    required this.modelUsed,
    this.systemPrompt,
    List<ChatMessage>? messages,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now(),
        messages = messages ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
      'modelUsed': modelUsed,
      'systemPrompt': systemPrompt,
      'messages': messages.map((m) => m.toJson()).toList(),
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled Chat',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      modifiedAt: json['modifiedAt'] != null
          ? DateTime.tryParse(json['modifiedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      modelUsed: json['modelUsed'] as String? ?? 'Unknown Model',
      systemPrompt: json['systemPrompt'] as String?,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
