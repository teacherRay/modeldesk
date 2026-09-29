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
  test('Phase 1 Milestone Freeze: Full Lifecycle Resilience Test', () async {
    print('\n======================================================');
    print('STEP 1: LAUNCH SERVER WITH KNOWN CONFIGURATION');
    print('======================================================');

    final config = ServerConfig.knownWorkingDefault();
    var processService = ProcessService();
    var llamaClient = LlamaClient();
    var storageService = StorageService();
    await storageService.init();

    var serverController = ServerController(
      processService: processService,
      llamaClient: llamaClient,
      storageService: storageService,
    );

    var chatController = ChatController(
      llamaClient: llamaClient,
      storageService: storageService,
    );

    processService.logStream.listen((line) {
      if (line.contains('listening') || line.contains('slot') || line.contains('LAUNCHER')) {
        print('[LOG] $line');
      }
    });

    final started = await serverController.startServer();
    expect(started, isTrue, reason: 'Failed to start llama-server');

    print('Waiting for server to become healthy...');
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
      await Future.delayed(const Duration(milliseconds: 600));
    }
    expect(isLive, isTrue, reason: 'Server did not become healthy in time');
    print('✓ Server is running on ${config.baseUrl}');

    print('\n======================================================');
    print('STEP 2: SEND PROMPT & STOP MID-GENERATION');
    print('======================================================');

    chatController.createNewChat();
    final convId = chatController.activeConversation!.id;
    const longPrompt = 'Write an extensive list of 10 reasons why local AI is beneficial for privacy and latency, with a paragraph for each.';
    print('Sending prompt: "$longPrompt"');

    final stopTriggered = Completer<void>();
    var partialText = '';

    void streamWatcher() {
      final conv = chatController.activeConversation;
      if (conv != null && conv.messages.length >= 2) {
        final assistantMsg = conv.messages.last;
        // As soon as at least 15 characters are received, stop generation!
        if (assistantMsg.content.length > 15 && !stopTriggered.isCompleted) {
          print('Generated ${assistantMsg.content.length} chars. Triggering STOP mid-generation!');
          partialText = assistantMsg.content;
          chatController.stopGeneration();
          if (!stopTriggered.isCompleted) {
            stopTriggered.complete();
          }
        }
      }
    }

    chatController.addListener(streamWatcher);

    await chatController.sendMessage(longPrompt, baseUrl: config.baseUrl);
    await stopTriggered.future.timeout(const Duration(seconds: 60));

    chatController.removeListener(streamWatcher);

    // Give state machine a moment to finish cancellation and persist
    await Future.delayed(const Duration(milliseconds: 500));

    expect(chatController.isGenerating, isFalse, reason: 'chatController is still generating after stop');
    expect(partialText, isNotEmpty, reason: 'No partial tokens captured before stop');
    print('✓ Stopped mid-generation successfully.');
    print('Partial text preserved: "$partialText"');

    print('\n======================================================');
    print('STEP 3 & 4: CLOSE APP → REOPEN → RESTORE JSON CONVERSATION');
    print('======================================================');

    // Simulate closing app completely
    chatController.dispose();
    serverController.dispose();

    print('App closed. Simulating restart with fresh instances...');

    // Fresh instances
    storageService = StorageService();
    await storageService.init();

    llamaClient = LlamaClient();
    processService = ProcessService();

    serverController = ServerController(
      processService: processService,
      llamaClient: llamaClient,
      storageService: storageService,
    );

    chatController = ChatController(
      llamaClient: llamaClient,
      storageService: storageService,
    );

    // Wait for storage to load
    await Future.delayed(const Duration(milliseconds: 600));

    // Verify conversation was restored
    expect(chatController.conversations, isNotEmpty, reason: 'Conversations list is empty after restart');
    final restoredConv = chatController.conversations.firstWhere((c) => c.id == convId);
    chatController.selectConversation(restoredConv.id);

    expect(restoredConv.messages.length, equals(2));
    expect(restoredConv.messages[0].role, equals('user'));
    expect(restoredConv.messages[0].content, equals(longPrompt));
    expect(restoredConv.messages[1].role, equals('assistant'));
    expect(restoredConv.messages[1].content, equals(partialText));
    print('✓ JSON conversation restored identically from disk:');
    print('  - Message 1 (User): ${restoredConv.messages[0].content.substring(0, 35)}...');
    print('  - Message 2 (Assistant Partial): ${restoredConv.messages[1].content}');

    print('\n======================================================');
    print('STEP 5: CONTINUE SAME CONVERSATION');
    print('======================================================');

    const continuePrompt = 'Now summarize those points into a single short sentence.';
    print('Sending follow-up prompt in same conversation: "$continuePrompt"');

    final continueDone = Completer<void>();
    var followUpResponse = '';

    void continueWatcher() {
      final conv = chatController.activeConversation;
      if (conv != null && conv.messages.length >= 4) {
        final lastMsg = conv.messages.last;
        if (!chatController.isGenerating && lastMsg.content.isNotEmpty && !continueDone.isCompleted) {
          followUpResponse = lastMsg.content;
          continueDone.complete();
        }
      }
    }

    chatController.addListener(continueWatcher);
    await chatController.sendMessage(continuePrompt, baseUrl: config.baseUrl);
    await continueDone.future.timeout(const Duration(seconds: 120));
    chatController.removeListener(continueWatcher);

    expect(followUpResponse, isNotEmpty, reason: 'Follow-up response was empty');
    expect(restoredConv.messages.length, equals(4));
    print('✓ Follow-up response received:');
    print('  "$followUpResponse"');
    print('✓ Total messages in restored session: ${restoredConv.messages.length}');

    print('\n======================================================');
    print('STEP 6: STOP SERVER');
    print('======================================================');

    print('Stopping server...');
    await serverController.stopServer();
    await Future.delayed(const Duration(milliseconds: 1000));

    final isOffline = !(await llamaClient.checkHealth(config.baseUrl));
    expect(isOffline, isTrue, reason: 'Server is still responding after stopServer');
    print('✓ Server stopped cleanly.');

    print('\n======================================================');
    print('STEP 7: RESTART SERVER');
    print('======================================================');

    print('Restarting server...');
    final restarted = await serverController.startServer();
    expect(restarted, isTrue, reason: 'Failed to restart server');

    final restartWait = DateTime.now().add(const Duration(seconds: 60));
    bool isRestartLive = false;
    while (DateTime.now().isBefore(restartWait)) {
      if (serverController.isRunning) {
        isRestartLive = true;
        break;
      }
      final healthy = await llamaClient.checkHealth(config.baseUrl);
      if (healthy) {
        await processService.markAsRunning();
        isRestartLive = true;
        break;
      }
      await Future.delayed(const Duration(milliseconds: 600));
    }
    expect(isRestartLive, isTrue, reason: 'Server did not come back online after restart');
    print('✓ Server restarted and listening on ${config.baseUrl}');

    print('\n======================================================');
    print('STEP 8: CHAT AGAIN AFTER SERVER RESTART');
    print('======================================================');

    const finalPrompt = 'Confirm you are operational after the restart by replying: "Server restart test passed".';
    print('Sending 3rd prompt after restart: "$finalPrompt"');

    final finalDone = Completer<void>();
    var finalResponse = '';

    void finalWatcher() {
      final conv = chatController.activeConversation;
      if (conv != null && conv.messages.length >= 6) {
        final lastMsg = conv.messages.last;
        if (!chatController.isGenerating && lastMsg.content.isNotEmpty && !finalDone.isCompleted) {
          finalResponse = lastMsg.content;
          finalDone.complete();
        }
      }
    }

    chatController.addListener(finalWatcher);
    await chatController.sendMessage(finalPrompt, baseUrl: config.baseUrl);
    await finalDone.future.timeout(const Duration(seconds: 120));
    chatController.removeListener(finalWatcher);

    expect(finalResponse, isNotEmpty, reason: 'Final response after restart was empty');
    expect(restoredConv.messages.length, equals(6));
    print('✓ Final response received after server restart:');
    print('  "$finalResponse"');

    print('\n======================================================');
    print('STEP 9: FINAL VERIFICATION & CLEANUP');
    print('======================================================');

    // Reload from storage one final time to verify all 6 messages persisted
    final verifyStorage = StorageService();
    await verifyStorage.init();
    final allSaved = await verifyStorage.loadAllConversations();
    final verifiedConv = allSaved.firstWhere((c) => c.id == convId);

    expect(verifiedConv.messages.length, equals(6));
    print('✓ Verified all 6 conversation turns persisted to JSON on disk.');

    // Stop server
    await serverController.stopServer();
    print('✓ Final shutdown complete.');

    print('\n======================================================');
    print('ALL MILESTONE FREEZE CRITERIA PASSED SUCCESSFULLY!');
    print('======================================================\n');
  }, timeout: const Timeout(Duration(minutes: 6)));
}
