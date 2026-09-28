import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/chat_message.dart';
import 'package:llama_launcher_flutter/models/conversation.dart';
import 'package:llama_launcher_flutter/models/server_config.dart';

void main() {
  test('ServerConfig builds valid command arguments', () {
    final config = ServerConfig.knownWorkingDefault();
    final args = config.buildCommandArgs();
    expect(args, contains('serve'));
    expect(args, contains('-m'));
    expect(args, contains('-ngl'));
    expect(args, contains('18'));
  });

  test('Conversation JSON serialization roundtrip', () {
    final conv = Conversation(
      id: 'test-123',
      title: 'Test Chat',
      modelUsed: 'test-model',
      messages: [
        ChatMessage(
          id: 'msg-1',
          role: 'user',
          content: 'Hello local AI',
        ),
        ChatMessage(
          id: 'msg-2',
          role: 'assistant',
          content: 'Hello! How can I help you?',
          tokensPerSecond: 24.5,
        ),
      ],
    );

    final json = conv.toJson();
    final restored = Conversation.fromJson(json);

    expect(restored.id, equals('test-123'));
    expect(restored.title, equals('Test Chat'));
    expect(restored.messages.length, equals(2));
    expect(restored.messages.first.content, equals('Hello local AI'));
    expect(restored.messages.last.tokensPerSecond, equals(24.5));
  });
}
