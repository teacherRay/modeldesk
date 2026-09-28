import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:llama_launcher_flutter/models/chat_message.dart';
import 'package:llama_launcher_flutter/models/conversation.dart';
import 'package:llama_launcher_flutter/models/server_config.dart';
import 'package:llama_launcher_flutter/services/model_scanner_service.dart';

void main() {
  test('ServerConfig builds valid command arguments with full parameters', () {
    final config = ServerConfig(
      llamaBin: r'C:\llama\llama.exe',
      modelPath: r'C:\models\qwen.gguf',
      mmprojPath: r'C:\models\mmproj.gguf',
      nGpuLayers: 33,
      threads: 8,
      ctxSize: '16384',
      flashAttn: 'on',
      cacheTypeK: 'q4_0',
      cacheTypeV: 'q4_0',
      parallel: 2,
      host: '0.0.0.0',
      port: '9090',
      mlock: true,
      extraArgs: '-lv 3 --no-mmap',
    );

    final args = config.buildCommandArgs();
    expect(args, contains('serve'));
    expect(args, contains('-m'));
    expect(args, contains(r'C:\models\qwen.gguf'));
    expect(args, contains('--mmproj'));
    expect(args, contains(r'C:\models\mmproj.gguf'));
    expect(args, contains('-ngl'));
    expect(args, contains('33'));
    expect(args, contains('-t'));
    expect(args, contains('8'));
    expect(args, contains('-c'));
    expect(args, contains('16384'));
    expect(args, contains('-fa'));
    expect(args, contains('on'));
    expect(args, contains('-ctk'));
    expect(args, contains('q4_0'));
    expect(args, contains('-ctv'));
    expect(args, contains('q4_0'));
    expect(args, contains('-np'));
    expect(args, contains('2'));
    expect(args, contains('--host'));
    expect(args, contains('0.0.0.0'));
    expect(args, contains('--port'));
    expect(args, contains('9090'));
    expect(args, contains('--mlock'));
    expect(args, contains('-lv'));
    expect(args, contains('--no-mmap'));

    // Command preview
    final preview = config.commandPreview;
    expect(preview, contains('"C:\\llama\\llama.exe"'));
    expect(preview, contains('--mmproj'));
    expect(preview, contains('--mlock'));
  });

  test('ModelScannerService discovers models and pairs matching mmprojs', () async {
    // Create a temporary directory structure for testing
    final tempDir = Directory.systemTemp.createTempSync('modeldesk_test_');
    try {
      final modelFile = File(p.join(tempDir.path, 'gemma-4b-q4.gguf'))..createSync();
      final mmprojFile = File(p.join(tempDir.path, 'mmproj-gemma-4b.gguf'))..createSync();
      File(p.join(tempDir.path, 'readme.txt')).createSync(); // Not a gguf

      final scanner = ModelScannerService(initialDirs: [tempDir.path], includeDefaultDirs: false);
      await scanner.rescan();

      expect(scanner.models.length, equals(1));
      expect(scanner.models.first.name, equals('gemma-4b-q4.gguf'));
      expect(scanner.models.first.isVisionMmproj, isFalse);

      expect(scanner.mmprojs.length, equals(1));
      expect(scanner.mmprojs.first.name, equals('mmproj-gemma-4b.gguf'));
      expect(scanner.mmprojs.first.isVisionMmproj, isTrue);

      // Verify automatic pairing of mmproj in the same folder
      final matched = scanner.findMatchingMmproj(modelFile.path);
      expect(matched, equals(p.normalize(mmprojFile.path)));
    } finally {
      tempDir.deleteSync(recursive: true);
    }
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
