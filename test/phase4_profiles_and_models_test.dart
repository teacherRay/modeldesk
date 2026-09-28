import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/gguf_model.dart';
import 'package:llama_launcher_flutter/models/model_profile.dart';
import 'package:llama_launcher_flutter/models/server_config.dart';
import 'package:llama_launcher_flutter/services/storage_service.dart';
import 'package:llama_launcher_flutter/services/process_service.dart';
import 'package:llama_launcher_flutter/services/llama_client.dart';
import 'package:llama_launcher_flutter/services/model_scanner_service.dart';
import 'package:llama_launcher_flutter/controllers/server_controller.dart';
import 'package:llama_launcher_flutter/controllers/profile_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 4: GGUF Model Metadata Extraction', () {
    test('Extracts architecture family, quantization, and parameter size accurately', () {
      final gemma = GgufModelInfo(
        name: 'gemma-4-26B-A4B-it-Q4_K_M.gguf',
        path: r'C:\models\gemma-4-26B-A4B-it-Q4_K_M.gguf',
        sizeBytes: 16 * 1024 * 1024 * 1024,
        isVisionMmproj: false,
      );
      expect(gemma.architectureFamily, equals('Gemma'));
      expect(gemma.quantization, equals('Q4_K_M'));
      expect(gemma.parameterSize, equals('26B'));

      final qwen = GgufModelInfo(
        name: 'qwen2.5-coder-7b-instruct-q8_0.gguf',
        path: r'C:\models\qwen2.5-coder-7b-instruct-q8_0.gguf',
        sizeBytes: 8 * 1024 * 1024 * 1024,
        isVisionMmproj: false,
      );
      expect(qwen.architectureFamily, equals('Qwen'));
      expect(qwen.quantization, equals('Q8_0'));
      expect(qwen.parameterSize, equals('7B'));

      final deepseek = GgufModelInfo(
        name: 'DeepSeek-R1-Distill-Qwen-14B-Q5_K_M.gguf',
        path: r'C:\models\DeepSeek-R1-Distill-Qwen-14B-Q5_K_M.gguf',
        sizeBytes: 10 * 1024 * 1024 * 1024,
        isVisionMmproj: false,
      );
      expect(deepseek.architectureFamily, equals('DeepSeek'));
      expect(deepseek.quantization, equals('Q5_K_M'));
      expect(deepseek.parameterSize, equals('14B'));

      final mmproj = GgufModelInfo(
        name: 'mmproj-gemma-4-f16.gguf',
        path: r'C:\models\mmproj-gemma-4-f16.gguf',
        sizeBytes: 500 * 1024 * 1024,
        isVisionMmproj: true,
      );
      expect(mmproj.architectureFamily, equals('Vision Projector'));
      expect(mmproj.quantization, equals('F16'));
    });
  });

  group('Phase 4: ModelProfile Data Model', () {
    test('JSON serialization roundtrip preserves all profile fields', () {
      final original = ModelProfile.create(
        name: 'Gemma 4 Vision Tuned',
        description: 'Tuned for 16GB VRAM with vision projector',
        modelPath: r'C:\models\gemma-4-26b.gguf',
        mmprojPath: r'C:\models\mmproj-gemma.gguf',
        nGpuLayers: 18,
        threads: 6,
        ctxSize: '16384',
        flashAttn: 'on',
        cacheTypeK: 'q8_0',
        cacheTypeV: 'q8_0',
        parallel: 2,
        host: '127.0.0.1',
        port: '8080',
        mlock: true,
        extraArgs: '--no-mmap',
        isDefault: true,
      );

      final json = original.toJson();
      final restored = ModelProfile.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.name, equals(original.name));
      expect(restored.description, equals(original.description));
      expect(restored.modelPath, equals(original.modelPath));
      expect(restored.mmprojPath, equals(original.mmprojPath));
      expect(restored.modelFileName, equals('gemma-4-26b.gguf'));
      expect(restored.mmprojFileName, equals('mmproj-gemma.gguf'));
      expect(restored.nGpuLayers, equals(18));
      expect(restored.threads, equals(6));
      expect(restored.ctxSize, equals('16384'));
      expect(restored.flashAttn, equals('on'));
      expect(restored.cacheTypeK, equals('q8_0'));
      expect(restored.cacheTypeV, equals('q8_0'));
      expect(restored.parallel, equals(2));
      expect(restored.mlock, isTrue);
      expect(restored.extraArgs, equals('--no-mmap'));
      expect(restored.isDefault, isTrue);
    });

    test('applyToConfig correctly updates ServerConfig with profile settings', () {
      final baseConfig = ServerConfig.knownWorkingDefault();
      final profile = ModelProfile.create(
        name: 'High Performance Preset',
        modelPath: r'C:\models\qwen.gguf',
        mmprojPath: r'C:\models\mmproj.gguf',
        nGpuLayers: 99,
        threads: 12,
        ctxSize: '32768',
        flashAttn: 'on',
        cacheTypeK: 'q4_0',
        cacheTypeV: 'q4_0',
        parallel: 4,
        port: '9090',
        mlock: true,
        extraArgs: '--cont-batching',
      );

      final applied = profile.applyToConfig(baseConfig);

      expect(applied.modelPath, equals(r'C:\models\qwen.gguf'));
      expect(applied.mmprojPath, equals(r'C:\models\mmproj.gguf'));
      expect(applied.nGpuLayers, equals(99));
      expect(applied.threads, equals(12));
      expect(applied.ctxSize, equals('32768'));
      expect(applied.flashAttn, equals('on'));
      expect(applied.cacheTypeK, equals('q4_0'));
      expect(applied.cacheTypeV, equals('q4_0'));
      expect(applied.parallel, equals(4));
      expect(applied.port, equals('9090'));
      expect(applied.mlock, isTrue);
      expect(applied.extraArgs, equals('--cont-batching'));
    });
  });

  group('Phase 4: ProfileController & Storage Integration', () {
    test('Seeds starter profiles, creates, duplicates, and applies profile', () async {
      final tempDir = Directory.systemTemp.createTempSync('modeldesk_p4_storage_');
      final storage = StorageService();
      await storage.init(customPath: tempDir.path);

      final controller = ProfileController(storageService: storage);
      await controller.loadProfiles();

      // Verify starter profiles seeded
      expect(controller.profiles.length, greaterThanOrEqualTo(3));
      final starterNames = controller.profiles.map((p) => p.name).toList();
      expect(starterNames, contains('Max GPU Offload (99 Layers)'));
      expect(starterNames, contains('Large Context 32K (KV Quantized)'));
      expect(starterNames, contains('CPU Fallback (Low VRAM)'));

      // Create new profile
      final newProfile = ModelProfile.create(
        name: 'Test Profile Alpha',
        modelPath: r'C:\models\test-model.gguf',
        nGpuLayers: 42,
        threads: 8,
        ctxSize: '16384',
      );
      await controller.createProfile(newProfile);
      expect(controller.profiles.any((p) => p.name == 'Test Profile Alpha'), isTrue);

      // Duplicate profile
      final duplicated = await controller.duplicateProfile(newProfile);
      expect(duplicated.name, equals('Test Profile Alpha (Copy)'));
      expect(duplicated.nGpuLayers, equals(42));
      expect(controller.profiles.any((p) => p.name == 'Test Profile Alpha (Copy)'), isTrue);

      // Find profile for model
      final matched = controller.findProfileForModel(r'C:\models\test-model.gguf');
      expect(matched, isNotNull);
      expect(matched!.name, contains('Test Profile Alpha'));

      // Apply profile to ServerController
      final processService = ProcessService();
      final llamaClient = LlamaClient();
      final scanner = ModelScannerService(includeDefaultDirs: false);
      final serverController = ServerController(
        processService: processService,
        llamaClient: llamaClient,
        storageService: storage,
        scanner: scanner,
      );

      controller.applyProfile(newProfile, serverController);
      expect(controller.activeProfile?.id, equals(newProfile.id));
      expect(serverController.config.nGpuLayers, equals(42));
      expect(serverController.config.ctxSize, equals('16384'));
      expect(serverController.config.commandPreview, contains('-ngl 42'));

      // Cleanup created profiles
      await controller.deleteProfile(newProfile.id);
      await controller.deleteProfile(duplicated.id);
      expect(controller.profiles.any((p) => p.id == newProfile.id), isFalse);
    });
  });
}
