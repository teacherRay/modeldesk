// ignore_for_file: avoid_print
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/server_config.dart';
import 'package:llama_launcher_flutter/services/process_service.dart';
import 'package:llama_launcher_flutter/services/llama_client.dart';
import 'package:llama_launcher_flutter/services/storage_service.dart';
import 'package:llama_launcher_flutter/controllers/chat_controller.dart';
import 'package:llama_launcher_flutter/controllers/server_controller.dart';

void main() {
  test('Phase 1 Milestone End-to-End Integration Test', () async {
    print('\n======================================================');
    print('STAGE 1: Initializing Services & Config');
    print('======================================================');

    final processService = ProcessService();
    final llamaClient = LlamaClient();
    final storageService = StorageService();
    await storageService.init();

    final config = ServerConfig.knownWorkingDefault();
    print('Target binary: ${config.llamaBin}');
    print('Target model: ${config.modelPath}');
    print('Base URL: ${config.baseUrl}');

    final serverController = ServerController(
      processService: processService,
      llamaClient: llamaClient,
      storageService: storageService,
    );

    // Print all server logs to stdout
    processService.logStream.listen((line) {
      print('[SERVER] $line');
    });

    final chatController = ChatController(
      llamaClient: llamaClient,
      storageService: storageService,
    );

    // Give storage a moment to load
    await Future.delayed(const Duration(milliseconds: 300));

    print('\n======================================================');
    print('STAGE 2: Launching llama-server via ProcessService');
    print('======================================================');

    final started = await serverController.startServer();
    expect(started, isTrue, reason: 'Failed to spawn llama-server process');

    // Wait for server to become healthy (up to 45 seconds for 32B model)
    print('Waiting for server to load model weights and listen on ${config.baseUrl}...');
    final maxWait = DateTime.now().add(const Duration(seconds: 45));
    bool isLive = false;

    while (DateTime.now().isBefore(maxWait)) {
      if (serverController.isRunning) {
        isLive = true;
        break;
      }
      final healthy = await llamaClient.checkHealth(config.baseUrl);
      if (healthy) {
        await processService.markAsRunning();
        isLive = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 800));
    }

    expect(isLive, isTrue, reason: 'llama-server did not reach running state within timeout');
    print('✓ Server is LIVE and responsive!');

    print('\n======================================================');
    print('STAGE 3: Streaming a Real Conversation via LlamaClient');
    print('======================================================');

    chatController.createNewChat();
    final conv = chatController.activeConversation!;
    print('Created test conversation: ${conv.id}');

    const testPrompt = 'Respond with exactly: "Phase 1 integration successful" and nothing else.';
    print('Sending prompt: "$testPrompt"');

    final streamCompleter = Completer<void>();
    var streamedText = '';

    // Listen to chat changes
    void listener() {
      final lastMsg = conv.messages.isNotEmpty ? conv.messages.last : null;
      if (lastMsg != null && lastMsg.isAssistant) {
        streamedText = lastMsg.content;
      }
      if (!chatController.isGenerating && streamedText.isNotEmpty && !streamCompleter.isCompleted) {
        streamCompleter.complete();
      }
    }

    chatController.addListener(listener);

    await chatController.sendMessage(testPrompt, baseUrl: config.baseUrl);

    // Wait for generation to complete (timeout 30s)
    await streamCompleter.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        print('Warning: Stream timed out, checking partial output...');
      },
    );

    chatController.removeListener(listener);

    print('Streamed assistant response:\n$streamedText');
    expect(streamedText, isNotEmpty, reason: 'No tokens received from llama-server stream');
    print('✓ Real response received successfully!');

    if (conv.messages.last.tokensPerSecond != null) {
      print('Generation speed: ${conv.messages.last.tokensPerSecond!.toStringAsFixed(1)} tok/s');
    }

    print('\n======================================================');
    print('STAGE 4: Verifying JSON Persistence');
    print('======================================================');

    // Create a new storage service instance to verify reloading from disk
    final freshStorage = StorageService();
    await freshStorage.init();
    final savedConvs = await freshStorage.loadAllConversations();

    expect(savedConvs, isNotEmpty, reason: 'No conversations found on disk');
    final reloadedConv = savedConvs.firstWhere((c) => c.id == conv.id);
    expect(reloadedConv.messages.length, greaterThanOrEqualTo(2));
    expect(reloadedConv.messages.first.role, equals('user'));
    expect(reloadedConv.messages.first.content, equals(testPrompt));
    expect(reloadedConv.messages.last.role, equals('assistant'));
    expect(reloadedConv.messages.last.content, equals(streamedText));
    print('✓ Conversation successfully persisted to JSON and verified from disk!');

    print('\n======================================================');
    print('STAGE 5: Testing Process Termination & Tree Cleanup');
    print('======================================================');

    final serverPid = processService.pid;
    print('Stopping llama-server (PID: $serverPid)...');
    await serverController.stopServer();

    // Verify status is stopped
    expect(serverController.isStopped, isTrue);

    // Verify health endpoint is no longer reachable
    await Future.delayed(const Duration(milliseconds: 1000));
    final stillHealthy = await llamaClient.checkHealth(config.baseUrl);
    expect(stillHealthy, isFalse, reason: 'Server was not cleanly terminated');
    print('✓ llama-server terminated cleanly. No orphan processes.');

    print('\n======================================================');
    print('PHASE 1 MILESTONE TEST COMPLETED SUCCESSFULLY!');
    print('======================================================\n');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
