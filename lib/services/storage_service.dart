import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/conversation.dart';
import '../models/server_config.dart';

class StorageService {
  Directory? _dataDir;
  Directory? _chatsDir;

  Future<void> init() async {
    try {
      final appSupport = await getApplicationSupportDirectory();
      _dataDir = Directory(p.join(appSupport.path, 'LlamaLauncher'));
    } catch (_) {
      // Fallback to local user profile directory
      final userProfile = Platform.environment['USERPROFILE'] ?? '.';
      _dataDir = Directory(p.join(userProfile, '.llama_launcher_flutter'));
    }

    if (!await _dataDir!.exists()) {
      await _dataDir!.create(recursive: true);
    }

    _chatsDir = Directory(p.join(_dataDir!.path, 'chats'));
    if (!await _chatsDir!.exists()) {
      await _chatsDir!.create(recursive: true);
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
            // Log corrupted file and skip without crashing
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

  // --- Server Config ---

  Future<ServerConfig> loadServerConfig() async {
    await _ensureInitialized();
    final configFile = File(p.join(_dataDir!.path, 'server_config.json'));
    if (await configFile.exists()) {
      try {
        final content = await configFile.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        return ServerConfig.fromJson(json);
      } catch (e) {
        debugPrint('Error reading server_config.json: $e');
      }
    }
    // Return known working default
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

  Future<void> _ensureInitialized() async {
    if (_dataDir == null || _chatsDir == null) {
      await init();
    }
  }
}
