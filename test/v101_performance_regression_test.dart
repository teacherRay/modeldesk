import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/server_config.dart';
import 'package:llama_launcher_flutter/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('v1.0.1 Performance Correction: ServerConfig & GPU Layers', () {
    test('Default ServerConfig offloads 99 GPU layers and specifies configVersion 2', () {
      final config = ServerConfig.knownWorkingDefault();
      expect(config.nGpuLayers, equals(99), reason: 'Default GPU layers must be 99 for full GPU offload');
      expect(config.configVersion, equals(2), reason: 'Default config version must be 2');
    });

    test('buildCommandArgs includes -lv 4 by default for GPU and VRAM visibility', () {
      final config = ServerConfig(
        llamaBin: r'C:\tools\llama.exe',
        modelPath: r'C:\models\test.gguf',
      );

      final args = config.buildCommandArgs();
      expect(args, contains('-lv'));
      final lvIndex = args.indexOf('-lv');
      expect(args[lvIndex + 1], equals('4'));
      expect(config.commandPreview, contains('-lv 4'));
    });

    test('buildCommandArgs respects custom -lv in extraArgs without duplicating', () {
      final config = ServerConfig(
        llamaBin: r'C:\tools\llama.exe',
        modelPath: r'C:\models\test.gguf',
        extraArgs: '-lv 2 --no-mmap',
      );

      final args = config.buildCommandArgs();
      final lvOccurrences = args.where((a) => a == '-lv').length;
      expect(lvOccurrences, equals(1));
      final lvIndex = args.indexOf('-lv');
      expect(args[lvIndex + 1], equals('2'));
      expect(args, isNot(contains('4')));
    });
  });

  group('v1.0.1 Performance Correction: Configuration Migration', () {
    late Directory tempDir;
    late StorageService storage;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('modeldesk_v101_migration_');
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

    test('Migrates legacy unversioned config with default 18 layers to 99 layers', () async {
      // Simulate existing legacy v1 config on disk with inherited 18
      final legacyJson = {
        'llama_bin': r'C:\tools\llama.exe',
        'model_path': r'C:\models\legacy.gguf',
        'n_gpu_layers': 18,
        'threads': 6,
        'ctx_size': '8192',
        // config_version missing (v1)
      };

      final configFile = File('${tempDir.path}/server_config.json');
      await configFile.writeAsString(jsonEncode(legacyJson));

      // Load through StorageService
      final loaded = await storage.loadServerConfig();

      expect(loaded.nGpuLayers, equals(99), reason: 'Legacy inherited 18 should be migrated to 99');
      expect(loaded.configVersion, equals(2));

      // Verify it was auto-persisted with config_version: 2 on disk
      final onDisk = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      expect(onDisk['config_version'], equals(2));
      expect(onDisk['n_gpu_layers'], equals(99));
    });

    test('Preserves intentionally customized legacy values (e.g. 42 or 0)', () async {
      // Simulate user who deliberately selected 42 layers in v1
      final customJson = {
        'llama_bin': r'C:\tools\llama.exe',
        'model_path': r'C:\models\legacy.gguf',
        'n_gpu_layers': 42,
        'threads': 8,
        'ctx_size': '4096',
      };

      final configFile = File('${tempDir.path}/server_config.json');
      await configFile.writeAsString(jsonEncode(customJson));

      final loaded = await storage.loadServerConfig();

      expect(loaded.nGpuLayers, equals(42), reason: 'Intentional customization to 42 must NOT be overwritten');
      expect(loaded.configVersion, equals(2));

      // Check on disk
      final onDisk = jsonDecode(await configFile.readAsString()) as Map<String, dynamic>;
      expect(onDisk['config_version'], equals(2));
      expect(onDisk['n_gpu_layers'], equals(42));
    });

    test('Preserves intentional 18 in version 2 config', () async {
      // Simulate user who deliberately chooses 18 in v2
      final v2Json = {
        'llama_bin': r'C:\tools\llama.exe',
        'model_path': r'C:\models\v2.gguf',
        'n_gpu_layers': 18,
        'config_version': 2,
      };

      final parsed = ServerConfig.fromJson(v2Json);
      expect(parsed.nGpuLayers, equals(18), reason: 'Deliberate choice of 18 in v2 must be preserved');
      expect(parsed.configVersion, equals(2));
    });
  });
}
