import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/conversation.dart';
import '../models/server_config.dart';
import '../models/model_profile.dart';
import '../models/app_settings.dart';

class StorageService {
  Directory? _dataDir;
  Directory? _chatsDir;
  Directory? _profilesDir;

  String get appDataPath => _dataDir?.path ?? '';

  Future<void> init({String? customPath}) async {
    if (customPath != null && customPath.isNotEmpty) {
      _dataDir = Directory(customPath);
    } else {
      try {
        final appSupport = await getApplicationSupportDirectory();
        _dataDir = Directory(p.join(appSupport.path, 'LlamaLauncher'));
      } catch (_) {
        // Fallback to local user profile directory
        final userProfile = Platform.environment['USERPROFILE'] ?? '.';
        _dataDir = Directory(p.join(userProfile, '.llama_launcher_flutter'));
      }
    }

    if (!await _dataDir!.exists()) {
      await _dataDir!.create(recursive: true);
    }

    _chatsDir = Directory(p.join(_dataDir!.path, 'chats'));
    if (!await _chatsDir!.exists()) {
      await _chatsDir!.create(recursive: true);
    }

    _profilesDir = Directory(p.join(_dataDir!.path, 'profiles'));
    if (!await _profilesDir!.exists()) {
      await _profilesDir!.create(recursive: true);
    }
  }

  // --- Conversations ---

  Future<List<Conversation>> loadAllConversations() async {
    await _ensureInitialized();
    final list = <Conversation>[];

    try {
      final files = _chatsDir!.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            list.add(Conversation.fromJson(json));
          } catch (e) {
            debugPrint('Warning: Corrupted conversation file skipped: ${file.path} ($e)');
          }
        }
      }
    } catch (e) {
      debugPrint('Error listing conversations: $e');
    }

    // Sort by modifiedAt descending
    list.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));
    return list;
  }

  Future<void> saveConversation(Conversation conv) async {
    await _ensureInitialized();
    try {
      final file = File(p.join(_chatsDir!.path, '${conv.id}.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(conv.toJson());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving conversation ${conv.id}: $e');
    }
  }

  Future<void> deleteConversation(String id) async {
    await _ensureInitialized();
    try {
      final file = File(p.join(_chatsDir!.path, '$id.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting conversation $id: $e');
    }
  }

  Future<void> clearAllConversations() async {
    await _ensureInitialized();
    try {
      final files = _chatsDir!.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.json')) {
          await f.delete();
        }
      }
    } catch (e) {
      debugPrint('Error clearing conversations: $e');
    }
  }

  // --- Model Profiles ---

  Future<List<ModelProfile>> loadAllProfiles() async {
    await _ensureInitialized();
    final list = <ModelProfile>[];

    try {
      final files = _profilesDir!.listSync().whereType<File>();
      for (final file in files) {
        if (file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            list.add(ModelProfile.fromJson(json));
          } catch (e) {
            debugPrint('Warning: Corrupted profile file skipped: ${file.path} ($e)');
          }
        }
      }
    } catch (e) {
      debugPrint('Error listing profiles: $e');
    }

    if (list.isEmpty) {
      final defaults = _createDefaultProfiles();
      for (final def in defaults) {
        await saveProfile(def);
        list.add(def);
      }
    }

    // Sort: default profiles first, then by modifiedAt descending
    list.sort((a, b) {
      if (a.isDefault && !b.isDefault) return -1;
      if (!a.isDefault && b.isDefault) return 1;
      return b.modifiedAt.compareTo(a.modifiedAt);
    });
    return list;
  }

  Future<void> saveProfile(ModelProfile profile) async {
    await _ensureInitialized();
    try {
      final file = File(p.join(_profilesDir!.path, '${profile.id}.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(profile.toJson());
      await file.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving profile ${profile.id}: $e');
    }
  }

  Future<void> deleteProfile(String id) async {
    await _ensureInitialized();
    try {
      final file = File(p.join(_profilesDir!.path, '$id.json'));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting profile $id: $e');
    }
  }

  Future<void> resetProfiles() async {
    await _ensureInitialized();
    try {
      final files = _profilesDir!.listSync().whereType<File>();
      for (final f in files) {
        if (f.path.endsWith('.json')) {
          await f.delete();
        }
      }
      final defaults = _createDefaultProfiles();
      for (final def in defaults) {
        await saveProfile(def);
      }
    } catch (e) {
      debugPrint('Error resetting profiles: $e');
    }
  }

  List<ModelProfile> _createDefaultProfiles() {
    return [
      ModelProfile.create(
        name: 'Max GPU Offload (99 Layers)',
        description: 'Offloads all layers to dedicated GPU VRAM with Flash Attention on.',
        modelPath: '',
        nGpuLayers: 99,
        threads: 6,
        ctxSize: '8192',
        flashAttn: 'on',
        cacheTypeK: 'q8_0',
        cacheTypeV: 'q8_0',
        isDefault: true,
      ),
      ModelProfile.create(
        name: 'Large Context 32K (KV Quantized)',
        description: 'Optimized for deep documents with 32K context and 4-bit KV cache quantization.',
        modelPath: '',
        nGpuLayers: 99,
        threads: 6,
        ctxSize: '32768',
        flashAttn: 'on',
        cacheTypeK: 'q4_0',
        cacheTypeV: 'q4_0',
      ),
      ModelProfile.create(
        name: 'CPU Fallback (Low VRAM)',
        description: 'Runs execution on CPU threads when VRAM is constrained.',
        modelPath: '',
        nGpuLayers: 0,
        threads: 8,
        ctxSize: '4096',
        flashAttn: 'off',
        cacheTypeK: 'f16',
        cacheTypeV: 'f16',
      ),
    ];
  }

  // --- Server Config ---

  Future<ServerConfig> loadServerConfig() async {
    await _ensureInitialized();
    final configFile = File(p.join(_dataDir!.path, 'server_config.json'));
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        final version = json['config_version'] as int? ?? 1;
        final config = ServerConfig.fromJson(json);

        // If from v1, write back the migrated config with config_version: 2
        if (version < 2) {
          await saveServerConfig(config);
        }
        return config;
      } catch (e) {
        debugPrint('Error reading server_config.json: $e');
      }
    }
    return ServerConfig.knownWorkingDefault();
  }

  Future<void> saveServerConfig(ServerConfig config) async {
    await _ensureInitialized();
    try {
      final configFile = File(p.join(_dataDir!.path, 'server_config.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(config.toJson());
      await configFile.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving server_config.json: $e');
    }
  }

  Future<void> resetServerConfig() async {
    await saveServerConfig(ServerConfig.knownWorkingDefault());
  }

  // --- App Settings ---

  Future<AppSettings> loadAppSettings() async {
    await _ensureInitialized();
    final settingsFile = File(p.join(_dataDir!.path, 'app_settings.json'));
    if (await settingsFile.exists()) {
      try {
        final content = await settingsFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return AppSettings.fromJson(json);
      } catch (e) {
        debugPrint('Error reading app_settings.json: $e');
      }
    }
    return AppSettings.defaultSettings();
  }

  Future<void> saveAppSettings(AppSettings settings) async {
    await _ensureInitialized();
    try {
      final settingsFile = File(p.join(_dataDir!.path, 'app_settings.json'));
      final jsonStr = const JsonEncoder.withIndent('  ').convert(settings.toJson());
      await settingsFile.writeAsString(jsonStr);
    } catch (e) {
      debugPrint('Error saving app_settings.json: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (_dataDir == null || _chatsDir == null || _profilesDir == null) {
      await init();
    }
  }
}
