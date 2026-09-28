import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/app_settings.dart';
import 'package:llama_launcher_flutter/models/conversation.dart';
import 'package:llama_launcher_flutter/core/theme.dart';
import 'package:llama_launcher_flutter/services/storage_service.dart';
import 'package:llama_launcher_flutter/services/llama_client.dart';
import 'package:llama_launcher_flutter/services/process_service.dart';
import 'package:llama_launcher_flutter/controllers/settings_controller.dart';
import 'package:llama_launcher_flutter/controllers/server_controller.dart';
import 'package:llama_launcher_flutter/controllers/chat_controller.dart';
import 'package:llama_launcher_flutter/controllers/profile_controller.dart';
import 'package:llama_launcher_flutter/controllers/hardware_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 5: AppSettings Data Model Tests', () {
    test('Default settings contain expected configuration', () {
      final settings = AppSettings.defaultSettings();
      expect(settings.themeMode, equals('catppuccin'));
      expect(settings.telemetryIntervalMs, equals(1500));
      expect(settings.autostartServer, isFalse);
      expect(settings.showHardwareBar, isTrue);
      expect(settings.enableSounds, isFalse);
    });

    test('JSON serialization roundtrip preserves all settings', () {
      final original = AppSettings(
        themeMode: 'midnight',
        telemetryIntervalMs: 3000,
        autostartServer: true,
        showHardwareBar: false,
        enableSounds: true,
      );

      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.themeMode, equals('midnight'));
      expect(restored.telemetryIntervalMs, equals(3000));
      expect(restored.autostartServer, isTrue);
      expect(restored.showHardwareBar, isFalse);
      expect(restored.enableSounds, isTrue);
    });

    test('copyWith updates specified fields only', () {
      final initial = AppSettings.defaultSettings();
      final updated = initial.copyWith(
        themeMode: 'nord',
        telemetryIntervalMs: 1500,
      );

      expect(updated.themeMode, equals('nord'));
      expect(updated.telemetryIntervalMs, equals(1500));
      expect(updated.autostartServer, equals(initial.autostartServer));
      expect(updated.showHardwareBar, equals(initial.showHardwareBar));
      expect(updated.enableSounds, equals(initial.enableSounds));
    });
  });

  group('Phase 5: Multi-Theme Engine Tests', () {
    test('AppTheme returns distinct ThemeData for each supported mode', () {
      final catppuccinTheme = AppTheme.getTheme('catppuccin');
      final midnightTheme = AppTheme.getTheme('midnight');
      final nordTheme = AppTheme.getTheme('nord');

      expect(catppuccinTheme.scaffoldBackgroundColor, equals(AppTheme.bgApp));
      expect(midnightTheme.scaffoldBackgroundColor, equals(AppTheme.midnightBg));
      expect(nordTheme.scaffoldBackgroundColor, equals(AppTheme.nordBg));

      // Unknown theme defaults to catppuccin
      final unknownTheme = AppTheme.getTheme('neon_unknown');
      expect(unknownTheme.scaffoldBackgroundColor, equals(AppTheme.bgApp));
    });

    test('Theme palettes have correct contrast and surface properties', () {
      final midnightTheme = AppTheme.getTheme('midnight');
      expect(midnightTheme.brightness, equals(Brightness.dark));
      expect(midnightTheme.colorScheme.surface, equals(AppTheme.midnightCard));

      final nordTheme = AppTheme.getTheme('nord');
      expect(nordTheme.brightness, equals(Brightness.dark));
      expect(nordTheme.colorScheme.surface, equals(AppTheme.nordCard));
    });
  });

  group('Phase 5: SettingsController & Data Maintenance Tests', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('modeldesk_p5_test_');
      storage = StorageService();
      await storage.init(customPath: tempDir.path);
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    test('Loads defaults and reacts to setting mutations with persistence', () async {
      final hardware = HardwareController();
      final controller = SettingsController(
        storageService: storage,
        hardwareController: hardware,
      );

      await controller.init();
      expect(controller.themeMode, equals('catppuccin'));
      expect(controller.telemetryIntervalMs, equals(1500));
      expect(controller.autostartServer, isFalse);
      expect(controller.showHardwareBar, isTrue);

      int notifyCount = 0;
      controller.addListener(() => notifyCount++);

      // Change theme
      await controller.setThemeMode('midnight');
      expect(controller.themeMode, equals('midnight'));

      // Change telemetry
      await controller.setTelemetryInterval(3000);
      expect(controller.telemetryIntervalMs, equals(3000));

      // Change autostart
      await controller.setAutostartServer(true);
      expect(controller.autostartServer, isTrue);

      // Change hardware bar visibility
      await controller.setShowHardwareBar(false);
      expect(controller.showHardwareBar, isFalse);

      expect(notifyCount, greaterThanOrEqualTo(4));

      // Verify persistence across new instance
      final freshController = SettingsController(storageService: storage);
      await freshController.init();
      expect(freshController.themeMode, equals('midnight'));
      expect(freshController.telemetryIntervalMs, equals(3000));
      expect(freshController.autostartServer, isTrue);
      expect(freshController.showHardwareBar, isFalse);

      hardware.dispose();
    });

    test('Data maintenance routines reset configs, profiles and clear chats', () async {
      final controller = SettingsController(storageService: storage);
      await controller.init();

      final serverController = ServerController(
        processService: ProcessService(),
        llamaClient: LlamaClient(),
        storageService: storage,
      );

      final profileController = ProfileController(storageService: storage);
      await profileController.loadProfiles();

      final chatController = ChatController(
        llamaClient: LlamaClient(),
        storageService: storage,
      );

      // 1. Mutate server config then reset
      serverController.setGpuLayers(88);
      serverController.setPort('7777');
      expect(serverController.config.nGpuLayers, equals(88));

      await controller.resetServerConfig(serverController);
      expect(serverController.config.port, equals('8080'));

      // 2. Add custom profile then reset profiles
      await profileController.createProfile(
        // ignore: prefer_const_constructors
        controller.settings.themeMode.isEmpty
            ? throw Exception()
            : profileController.profiles.first.copyWith(name: 'Disposable Profile'),
      );
      expect(profileController.profiles.any((p) => p.name == 'Disposable Profile'), isTrue);

      await controller.resetProfiles(profileController);
      expect(profileController.profiles.any((p) => p.name == 'Disposable Profile'), isFalse);

      // 3. Add custom conversation then clear all conversations
      final conv = Conversation(
        id: 'test-conv-999',
        title: 'Temporary Test Chat',
        modelUsed: 'test-model',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        messages: [],
      );
      await storage.saveConversation(conv);
      await chatController.reloadConversations();
      expect(chatController.conversations.any((c) => c.id == 'test-conv-999'), isTrue);

      await controller.clearAllConversations(chatController);
      expect(chatController.conversations.any((c) => c.id == 'test-conv-999'), isFalse);
    });
  });
}
