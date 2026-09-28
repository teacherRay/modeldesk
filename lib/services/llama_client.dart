import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/chat_message.dart';

class ChatStreamChunk {
  final String deltaText;
  final String? reasoningDelta;
  final bool isDone;
  final double? tokensPerSec;
  final int? totalTokens;

  ChatStreamChunk({
    this.deltaText = '',
    this.reasoningDelta,
    this.isDone = false,
    this.tokensPerSec,
    this.totalTokens,
  });
}

class LlamaClient {
  HttpClient? _activeClient;
  bool _isCancelled = false;

  Future<bool> checkHealth(String baseUrl) async {
    try {
      final uri = Uri.parse('$baseUrl/health');
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        return body.contains('"status":"ok"') ||
            body.contains('"status": "ok"') ||
            body.contains('"ok"') ||
            body.isNotEmpty;
      }
      return false;
    } catch (_) {
      try {
        final baseUri = Uri.parse(baseUrl);
        final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
        final request = await client.getUrl(baseUri);
        final response = await request.close();
        return response.statusCode == 200;
      } catch (_) {
        return false;
      }
    }
  }

  Stream<ChatStreamChunk> streamChatCompletion({
    required String baseUrl,
    required List<ChatMessage> conversationHistory,
    String? systemPrompt,
    String model = 'default',
    double temperature = 0.7,
  }) async* {
    _isCancelled = false;
    _activeClient = HttpClient();

    final messagesPayload = <Map<String, String>>[];
    if (systemPrompt != null && systemPrompt.trim().isNotEmpty) {
      messagesPayload.add({
        'role': 'system',
        'content': systemPrompt.trim(),
      });
    }

    for (final msg in conversationHistory) {
      messagesPayload.add({
        'role': msg.role,
        'content': msg.content,
      });
    }

    final requestBody = jsonEncode({
      'model': model,
      'messages': messagesPayload,
      'stream': true,
      'temperature': temperature,
    });

    final stopwatch = Stopwatch()..start();
    var tokenCount = 0;

    try {
      final uri = Uri.parse('$baseUrl/v1/chat/completions');
      final request = await _activeClient!.postUrl(uri);
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.write(requestBody);

      final response = await request.close();

      if (response.statusCode != 200) {
        final errorBody = await response.transform(utf8.decoder).join();
        yield ChatStreamChunk(
          deltaText: '\n[API Error ${response.statusCode}]: $errorBody',
          isDone: true,
        );
        return;
      }

      final lineStream = response
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        if (_isCancelled) {
          yield ChatStreamChunk(deltaText: ' [Stopped]', isDone: true);
          break;
        }

        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;

        if (trimmed.startsWith('data: ')) {
          final dataStr = trimmed.substring(6).trim();
          if (dataStr == '[DONE]') {
            stopwatch.stop();
            final durationSec = stopwatch.elapsedMilliseconds / 1000.0;
            final tps = durationSec > 0 ? (tokenCount / durationSec) : 0.0;
            yield ChatStreamChunk(
              isDone: true,
              tokensPerSec: tps,
              totalTokens: tokenCount,
            );
            break;
          }

          try {
            final parsed = jsonDecode(dataStr) as Map<String, dynamic>;
            final choices = parsed['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final firstChoice = choices[0] as Map<String, dynamic>;
              final delta = firstChoice['delta'] as Map<String, dynamic>?;

              if (delta != null) {
                final content = delta['content'] as String? ?? '';
                final reasoning = delta['reasoning_content'] as String?;

                if (content.isNotEmpty || reasoning != null) {
                  tokenCount++;
                  final durationSec = stopwatch.elapsedMilliseconds / 1000.0;
                  final currentTps =
                      durationSec > 0 ? (tokenCount / durationSec) : 0.0;

                  yield ChatStreamChunk(
                    deltaText: content,
                    reasoningDelta: reasoning,
                    isDone: false,
                    tokensPerSec: currentTps,
                    totalTokens: tokenCount,
                  );
                }
              }
            }
          } catch (_) {
            // Ignore partial SSE chunk parse errors
          }
        }
      }
    } catch (e) {
      if (!_isCancelled) {
        yield ChatStreamChunk(
          deltaText: '\n[Connection Error]: $e',
          isDone: true,
        );
      }
    } finally {
      _activeClient?.close(force: true);
      _activeClient = null;
    }
  }

  void cancel() {
    _isCancelled = true;
    _activeClient?.close(force: true);
    _activeClient = null;
  }
}
