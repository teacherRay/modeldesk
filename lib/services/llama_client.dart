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
  final int? promptTokens;
  final double? promptPerSec;
  final double? promptEvalTimeMs;
  final double? timeToFirstTokenMs;

  ChatStreamChunk({
    this.deltaText = '',
    this.reasoningDelta,
    this.isDone = false,
    this.tokensPerSec,
    this.totalTokens,
    this.promptTokens,
    this.promptPerSec,
    this.promptEvalTimeMs,
    this.timeToFirstTokenMs,
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
      'stream_options': {'include_usage': true},
      'temperature': temperature,
    });

    final dispatchStopwatch = Stopwatch()..start();
    double? actualTtftMs;
    Stopwatch? generationStopwatch;
    var receivedChunks = 0;
    double? authoritativeTps;
    int? authoritativeTotalTokens;
    int? authoritativePromptTokens;
    double? authoritativePromptPerSec;
    double? authoritativePromptEvalMs;

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
            generationStopwatch?.stop();
            final durationSec =
                (generationStopwatch?.elapsedMilliseconds ?? 0) / 1000.0;
            final fallbackTps =
                durationSec > 0 ? (receivedChunks / durationSec) : 0.0;

            final finalTps = authoritativeTps ?? fallbackTps;
            final finalTokens = authoritativeTotalTokens ?? receivedChunks;

            yield ChatStreamChunk(
              isDone: true,
              tokensPerSec: finalTps,
              totalTokens: finalTokens,
              promptTokens: authoritativePromptTokens,
              promptPerSec: authoritativePromptPerSec,
              promptEvalTimeMs: authoritativePromptEvalMs,
              timeToFirstTokenMs: actualTtftMs,
            );
            break;
          }

          try {
            final parsed = jsonDecode(dataStr) as Map<String, dynamic>;

            // Extract authoritative timings from llama.cpp if present
            final timings = parsed['timings'] as Map<String, dynamic>?;
            if (timings != null) {
              if (timings['predicted_per_second'] != null) {
                authoritativeTps =
                    (timings['predicted_per_second'] as num).toDouble();
              }
              if (timings['predicted_n'] != null) {
                authoritativeTotalTokens =
                    (timings['predicted_n'] as num).toInt();
              }
              if (timings['prompt_n'] != null) {
                authoritativePromptTokens =
                    (timings['prompt_n'] as num).toInt();
              }
              if (timings['prompt_per_second'] != null) {
                authoritativePromptPerSec =
                    (timings['prompt_per_second'] as num).toDouble();
              }
              if (timings['prompt_ms'] != null) {
                authoritativePromptEvalMs =
                    (timings['prompt_ms'] as num).toDouble();
              }
            }

            // Extract authoritative usage from OpenAI/llama.cpp usage block if present
            final usage = parsed['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              if (usage['completion_tokens'] != null) {
                authoritativeTotalTokens =
                    (usage['completion_tokens'] as num).toInt();
              }
              if (usage['prompt_tokens'] != null) {
                authoritativePromptTokens ??=
                    (usage['prompt_tokens'] as num).toInt();
              }
            }

            final choices = parsed['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final firstChoice = choices[0] as Map<String, dynamic>;
              final delta = firstChoice['delta'] as Map<String, dynamic>?;

              if (delta != null) {
                final content = delta['content'] as String? ?? '';
                final reasoning = delta['reasoning_content'] as String?;

                if (content.isNotEmpty || reasoning != null) {
                  // Actual TTFT measured from request dispatch until first generated chunk
                  if (actualTtftMs == null) {
                    actualTtftMs = dispatchStopwatch.elapsedMilliseconds.toDouble();
                    generationStopwatch ??= Stopwatch()..start();
                  }

                  receivedChunks++;

                  final durationSec =
                      (generationStopwatch?.elapsedMilliseconds ?? 0) / 1000.0;
                  final liveTps = (durationSec > 0.05 && receivedChunks >= 2)
                      ? (receivedChunks / durationSec)
                      : null;

                  yield ChatStreamChunk(
                    deltaText: content,
                    reasoningDelta: reasoning,
                    isDone: false,
                    tokensPerSec: authoritativeTps ?? liveTps,
                    totalTokens: authoritativeTotalTokens ?? receivedChunks,
                    promptTokens: authoritativePromptTokens,
                    promptPerSec: authoritativePromptPerSec,
                    promptEvalTimeMs: authoritativePromptEvalMs,
                    timeToFirstTokenMs: actualTtftMs,
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
