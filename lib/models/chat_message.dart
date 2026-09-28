class ChatMessage {
  final String id;
  final String role; // 'user' | 'assistant' | 'system'
  String content;
  String? reasoningContent;
  final DateTime timestamp;
  double? tokensPerSecond;
  int? totalTokens;
  int? evalDurationMs;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.reasoningContent,
    DateTime? timestamp,
    this.tokensPerSecond,
    this.totalTokens,
    this.evalDurationMs,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isSystem => role == 'system';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'content': content,
      'reasoningContent': reasoningContent,
      'timestamp': timestamp.toIso8601String(),
      'tokensPerSecond': tokensPerSecond,
      'totalTokens': totalTokens,
      'evalDurationMs': evalDurationMs,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      reasoningContent: json['reasoningContent'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      tokensPerSecond: (json['tokensPerSecond'] as num?)?.toDouble(),
      totalTokens: json['totalTokens'] as int?,
      evalDurationMs: json['evalDurationMs'] as int?,
    );
  }
}
