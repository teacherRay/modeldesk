import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:llama_launcher_flutter/models/server_config.dart';
import 'package:llama_launcher_flutter/services/storage_service.dart';
import 'package:llama_launcher_flutter/services/model_scanner_service.dart';
import 'package:llama_launcher_flutter/services/process_service.dart';
import 'package:llama_launcher_flutter/services/llama_client.dart';
import 'package:llama_launcher_flutter/controllers/server_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 2: ServerConfig Tests', () {
    test('Default configuration contains sensible defaults', () {
      final config = ServerConfig.knownWorkingDefault();
      expect(config.llamaBin, isNotEmpty);
      expect(config.baseUrl, equals('http://127.0.0.1:8080'));
      expect(config.port, equals('8080'));
      expect(config.host, equals('127.0.0.1'));
      expect(config.flashAttn, equals('on'));
      expect(config.cacheTypeK, equals('q8_0'));
      expect(config.cacheTypeV, equals('q8_0'));
      expect(config.parallel, equals(1));
    });

    test('JSON serialization roundtrip preserves all Phase 2 parameters', () {
      final original = ServerConfig(
        llamaBin: r'C:\tools\llama.exe',
        modelPath: r'C:\models\mistral.gguf',
        mmprojPath: r'C:\models\mmproj-mistral.gguf',
        nGpuLayers: 28,
        threads: 12,
        ctxSize: '32768',
        flashAttn: 'off',
        cacheTypeK: 'q4_0',
        cacheTypeV: 'q4_0',
        parallel: 4,
        host: '0.0.0.0',
        port: '8088',
        mlock: true,
        extraArgs: '--cont-batching --log-disable',
        customModelDirs: [r'D:\AI\Models', r'E:\LLMs'],
      );

      final json = original.toJson();
      final restored = ServerConfig.fromJson(json);

      expect(restored.llamaBin, equals(original.llamaBin));
      expect(restored.modelPath, equals(original.modelPath));
      expect(restored.mmprojPath, equals(original.mmprojPath));
      expect(restored.nGpuLayers, equals(28));
      expect(restored.threads, equals(12));
      expect(restored.ctxSize, equals('32768'));
      expect(restored.flashAttn, equals('off'));
      expect(restored.cacheTypeK, equals('q4_0'));
      expect(restored.cacheTypeV, equals('q4_0'));
      expect(restored.parallel, equals(4));
      expect(restored.host, equals('0.0.0.0'));
      expect(restored.port, equals('8088'));
      expect(restored.mlock, isTrue);
      expect(restored.extraArgs, equals('--cont-batching --log-disable'));
      expect(restored.customModelDirs, containsAll([r'D:\AI\Models', r'E:\LLMs']));
    });

    test('Command generation and preview accurately format all arguments', () {
      final config = ServerConfig(
        llamaBin: r'C:\bin\llama.exe',
        modelPath: r'C:\models\qwen-2.5-7b.gguf',
        mmprojPath: r'C:\models\mmproj-qwen.gguf',
        nGpuLayers: 99,
        threads: 8,
        ctxSize: '16384',
        flashAttn: 'on',
        cacheTypeK: 'f16',
        cacheTypeV: 'f16',
        parallel: 2,
        host: '127.0.0.1',
        port: '8080',
        mlock: true,
        extraArgs: '-lv 2',
      );

      final args = config.buildCommandArgs();
      expect(args, equals([
        'serve',
        '-m', r'C:\models\qwen-2.5-7b.gguf',
        '--mmproj', r'C:\models\mmproj-qwen.gguf',
        '-ngl', '99',
        '-t', '8',
        '-c', '16384',
        '-fa', 'on',
        '-ctk', 'f16',
        '-ctv', 'f16',
        '-np', '2',
        '--mlock',
        '--host', '127.0.0.1',
        '--port', '8080',
        '-lv', '2',
      ]));

      final preview = config.commandPreview;
      expect(preview, contains('"C:\\bin\\llama.exe" serve'));
      expect(preview, contains('-m "C:\\models\\qwen-2.5-7b.gguf"'));
      expect(preview, contains('--mmproj "C:\\models\\mmproj-qwen.gguf"'));
      expect(preview, contains('-ngl 99'));
      expect(preview, contains('--mlock'));
    });
  });

  group('Phase 2: ModelScannerService Tests', () {
    late Directory tempRoot;

    setUp(() {
      tempRoot = Directory.systemTemp.createTempSync('modeldesk_scan_');
    });

    tearDown(() {
      if (tempRoot.existsSync()) {
        tempRoot.deleteSync(recursive: true);
      }
    });

    test('Scans subdirectories and differentiates model weights from mmproj', () async {
      final subDirA = Directory(p.join(tempRoot.path, 'deepseek'))..createSync();
      final subDirB = Directory(p.join(tempRoot.path, 'vision'))..createSync();

      File(p.join(subDirA.path, 'deepseek-r1-7b.Q4_K_M.gguf')).createSync();
      File(p.join(subDirB.path, 'minicpm-v-2.6.gguf')).createSync();
      File(p.join(subDirB.path, 'mmproj-minicpm-v-2.6.gguf')).createSync();
      File(p.join(subDirA.path, 'config.json')).createSync(); // Non-gguf

      final scanner = ModelScannerService(
        initialDirs: [tempRoot.path],
        includeDefaultDirs: false,
      );
      await scanner.rescan();

      expect(scanner.models.length, equals(2));
      expect(scanner.mmprojs.length, equals(1));

      final modelNames = scanner.models.map((m) => m.name).toList();
      expect(modelNames, contains('deepseek-r1-7b.Q4_K_M.gguf'));
      expect(modelNames, contains('minicpm-v-2.6.gguf'));

      final mmprojNames = scanner.mmprojs.map((m) => m.name).toList();
      expect(mmprojNames, contains('mmproj-minicpm-v-2.6.gguf'));

      // Test pairing
      final minicpmModel = scanner.models.firstWhere((m) => m.name == 'minicpm-v-2.6.gguf');
      final paired = scanner.findMatchingMmproj(minicpmModel.path);
      expect(paired, isNotNull);
      expect(p.basename(paired!), equals('mmproj-minicpm-v-2.6.gguf'));

      // Test no pairing for subDirA
      final deepseekModel = scanner.models.firstWhere((m) => m.name.contains('deepseek'));
      final noPair = scanner.findMatchingMmproj(deepseekModel.path);
      expect(noPair, isNull);
    });

    test('Custom directory management persists and rescans', () async {
      final extraDir = Directory.systemTemp.createTempSync('modeldesk_extra_');
      try {
        File(p.join(extraDir.path, 'custom-model.gguf')).createSync();

        final scanner = ModelScannerService(
          initialDirs: [tempRoot.path],
          includeDefaultDirs: false,
        );
        await scanner.rescan();
        expect(scanner.models.isEmpty, isTrue);

        scanner.addDirectory(extraDir.path);
        expect(scanner.scanDirectories, contains(p.normalize(extraDir.path)));
        await scanner.rescan();
        expect(scanner.models.length, equals(1));
        expect(scanner.models.first.name, equals('custom-model.gguf'));

        scanner.removeDirectory(extraDir.path);
        expect(scanner.scanDirectories, isNot(contains(p.normalize(extraDir.path))));
        await scanner.rescan();
        expect(scanner.models.isEmpty, isTrue);
      } finally {
        if (extraDir.existsSync()) {
          extraDir.deleteSync(recursive: true);
        }
      }
    });
  });

  group('Phase 2: ServerController Integration Tests', () {
    test('ServerController dynamically updates config and notifies listeners', () async {
      final tempDir = Directory.systemTemp.createTempSync('modeldesk_p2_storage_');
      final storage = StorageService();
      await storage.init(customPath: tempDir.path);

      final scanner = ModelScannerService(includeDefaultDirs: false);
      final process = ProcessService();
      final client = LlamaClient();

      final controller = ServerController(
        processService: process,
        llamaClient: client,
        storageService: storage,
        scanner: scanner,
      );

      // Verify reactive parameter updates
      int notifications = 0;
      controller.addListener(() => notifications++);

      controller.setGpuLayers(42);
      expect(controller.config.nGpuLayers, equals(42));
      expect(controller.config.commandPreview, contains('-ngl 42'));

      controller.setThreads(16);
      expect(controller.config.threads, equals(16));
      expect(controller.config.commandPreview, contains('-t 16'));

      controller.setContextSize('16384');
      expect(controller.config.ctxSize, equals('16384'));
      expect(controller.config.commandPreview, contains('-c 16384'));

      controller.setFlashAttention('off');
      expect(controller.config.flashAttn, equals('off'));
      expect(controller.config.commandPreview, contains('-fa off'));

      controller.setParallel(3);
      expect(controller.config.parallel, equals(3));
      expect(controller.config.commandPreview, contains('-np 3'));

      controller.setMlock(true);
      expect(controller.config.mlock, isTrue);
      expect(controller.config.commandPreview, contains('--mlock'));

      controller.setPort('9999');
      expect(controller.config.port, equals('9999'));
      expect(controller.config.commandPreview, contains('--port 9999'));

      controller.setExtraArgs('--draft-model draft.gguf');
      expect(controller.config.extraArgs, equals('--draft-model draft.gguf'));
      expect(controller.config.commandPreview, contains('--draft-model draft.gguf'));

      expect(notifications, greaterThanOrEqualTo(8));

      // Wait a moment for async file save
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify persistence in storage
      final restored = await storage.loadServerConfig();
      expect(restored.nGpuLayers, equals(42));
      expect(restored.threads, equals(16));
      expect(restored.port, equals('9999'));
      expect(restored.mlock, isTrue);
    });
  });
}
