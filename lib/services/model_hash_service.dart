import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class ModelHashService {
  final String _cacheFilePath;
  final Map<String, Map<String, dynamic>> _cache = {};
  bool _initialized = false;

  ModelHashService({String? customCacheDir})
      : _cacheFilePath = p.join(
          customCacheDir ?? _defaultCacheDir(),
          'hash_cache.json',
        );

  static String _defaultCacheDir() {
    final userProfile = Platform.environment['USERPROFILE'] ?? '.';
    return p.join(userProfile, r'AppData\Roaming\LlamaLauncher\benchmarks');
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      final file = File(_cacheFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        for (final entry in json.entries) {
          if (entry.value is Map) {
            _cache[entry.key] = Map<String, dynamic>.from(entry.value as Map);
          }
        }
      }
    } catch (e) {
      debugPrint('[ModelHashService] Failed to load hash cache: $e');
    }
    _initialized = true;
  }

  Future<String> getOrComputeSha256(String filePath) async {
    await init();

    final file = File(filePath);
    if (!await file.exists()) return 'FILE_NOT_FOUND';

    try {
      final stat = await file.stat();
      final size = stat.size;
      final modifiedMs = stat.modified.millisecondsSinceEpoch;
      final normPath = p.normalize(filePath);

      // Check cache validity: must match exact path, size, and modification timestamp
      if (_cache.containsKey(normPath)) {
        final entry = _cache[normPath]!;
        if (entry['size'] == size && entry['modified_ms'] == modifiedMs) {
          final cachedHash = entry['sha256'] as String?;
          if (cachedHash != null && cachedHash.isNotEmpty) {
            return cachedHash;
          }
        }
      }

      // Compute streaming SHA-256
      debugPrint('[ModelHashService] Computing SHA-256 for: $normPath (${stat.size} bytes)...');
      final digest = await sha256.bind(file.openRead()).first;
      final hashStr = digest.toString();

      _cache[normPath] = {
        'size': size,
        'modified_ms': modifiedMs,
        'sha256': hashStr,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await _persistCache();
      return hashStr;
    } catch (e) {
      debugPrint('[ModelHashService] Error computing SHA-256: $e');
      return 'HASH_ERROR';
    }
  }

  Future<void> _persistCache() async {
    try {
      final file = File(_cacheFilePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }
      await file.writeAsString(jsonEncode(_cache));
    } catch (e) {
      debugPrint('[ModelHashService] Failed to persist hash cache: $e');
    }
  }
}
