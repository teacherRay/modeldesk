import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import 'server_config.dart';

class ModelProfile {
  final String id;
  final String name;
  final String description;
  final String modelPath;
  final String mmprojPath;
  final int nGpuLayers;
  final int threads;
  final String ctxSize;
  final String flashAttn;
  final String cacheTypeK;
  final String cacheTypeV;
  final int parallel;
  final String host;
  final String port;
  final bool mlock;
  final String extraArgs;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime modifiedAt;

  const ModelProfile({
    required this.id,
    required this.name,
    this.description = '',
    required this.modelPath,
    this.mmprojPath = '',
    this.nGpuLayers = 99,
    this.threads = 6,
    this.ctxSize = '8192',
    this.flashAttn = 'on',
    this.cacheTypeK = 'q8_0',
    this.cacheTypeV = 'q8_0',
    this.parallel = 1,
    this.host = '127.0.0.1',
    this.port = '8080',
    this.mlock = false,
    this.extraArgs = '',
    this.isDefault = false,
    required this.createdAt,
    required this.modifiedAt,
  });

  String get modelFileName => modelPath.isNotEmpty ? p.basename(modelPath) : '';
  String get mmprojFileName => mmprojPath.isNotEmpty ? p.basename(mmprojPath) : '';

  factory ModelProfile.create({
    required String name,
    String description = '',
    required String modelPath,
    String mmprojPath = '',
    int nGpuLayers = 99,
    int threads = 6,
    String ctxSize = '8192',
    String flashAttn = 'on',
    String cacheTypeK = 'q8_0',
    String cacheTypeV = 'q8_0',
    int parallel = 1,
    String host = '127.0.0.1',
    String port = '8080',
    bool mlock = false,
    String extraArgs = '',
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return ModelProfile(
      id: const Uuid().v4(),
      name: name,
      description: description,
      modelPath: modelPath,
      mmprojPath: mmprojPath,
      nGpuLayers: nGpuLayers,
      threads: threads,
      ctxSize: ctxSize,
      flashAttn: flashAttn,
      cacheTypeK: cacheTypeK,
      cacheTypeV: cacheTypeV,
      parallel: parallel,
      host: host,
      port: port,
      mlock: mlock,
      extraArgs: extraArgs,
      isDefault: isDefault,
      createdAt: now,
      modifiedAt: now,
    );
  }

  factory ModelProfile.fromServerConfig({
    required String name,
    String description = '',
    required ServerConfig config,
    bool isDefault = false,
  }) {
    final now = DateTime.now();
    return ModelProfile(
      id: const Uuid().v4(),
      name: name,
      description: description,
      modelPath: config.modelPath,
      mmprojPath: config.mmprojPath,
      nGpuLayers: config.nGpuLayers,
      threads: config.threads,
      ctxSize: config.ctxSize,
      flashAttn: config.flashAttn,
      cacheTypeK: config.cacheTypeK,
      cacheTypeV: config.cacheTypeV,
      parallel: config.parallel,
      host: config.host,
      port: config.port,
      mlock: config.mlock,
      extraArgs: config.extraArgs,
      isDefault: isDefault,
      createdAt: now,
      modifiedAt: now,
    );
  }

  ServerConfig applyToConfig(ServerConfig baseConfig) {
    return baseConfig.copyWith(
      modelPath: modelPath.isNotEmpty ? modelPath : baseConfig.modelPath,
      mmprojPath: mmprojPath,
      nGpuLayers: nGpuLayers,
      threads: threads,
      ctxSize: ctxSize,
      flashAttn: flashAttn,
      cacheTypeK: cacheTypeK,
      cacheTypeV: cacheTypeV,
      parallel: parallel,
      host: host,
      port: port,
      mlock: mlock,
      extraArgs: extraArgs,
    );
  }

  ModelProfile copyWith({
    String? name,
    String? description,
    String? modelPath,
    String? mmprojPath,
    int? nGpuLayers,
    int? threads,
    String? ctxSize,
    String? flashAttn,
    String? cacheTypeK,
    String? cacheTypeV,
    int? parallel,
    String? host,
    String? port,
    bool? mlock,
    String? extraArgs,
    bool? isDefault,
  }) {
    return ModelProfile(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      modelPath: modelPath ?? this.modelPath,
      mmprojPath: mmprojPath ?? this.mmprojPath,
      nGpuLayers: nGpuLayers ?? this.nGpuLayers,
      threads: threads ?? this.threads,
      ctxSize: ctxSize ?? this.ctxSize,
      flashAttn: flashAttn ?? this.flashAttn,
      cacheTypeK: cacheTypeK ?? this.cacheTypeK,
      cacheTypeV: cacheTypeV ?? this.cacheTypeV,
      parallel: parallel ?? this.parallel,
      host: host ?? this.host,
      port: port ?? this.port,
      mlock: mlock ?? this.mlock,
      extraArgs: extraArgs ?? this.extraArgs,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt,
      modifiedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'model_path': modelPath,
      'mmproj_path': mmprojPath,
      'n_gpu_layers': nGpuLayers,
      'threads': threads,
      'ctx_size': ctxSize,
      'flash_attn': flashAttn,
      'cache_type_k': cacheTypeK,
      'cache_type_v': cacheTypeV,
      'parallel': parallel,
      'host': host,
      'port': port,
      'mlock': mlock,
      'extra_args': extraArgs,
      'is_default': isDefault,
      'created_at': createdAt.toIso8601String(),
      'modified_at': modifiedAt.toIso8601String(),
    };
  }

  factory ModelProfile.fromJson(Map<String, dynamic> json) {
    return ModelProfile(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? 'Untitled Profile',
      description: json['description'] as String? ?? '',
      modelPath: json['model_path'] as String? ?? '',
      mmprojPath: json['mmproj_path'] as String? ?? '',
      nGpuLayers: json['n_gpu_layers'] as int? ?? 99,
      threads: json['threads'] as int? ?? 6,
      ctxSize: json['ctx_size']?.toString() ?? '8192',
      flashAttn: json['flash_attn'] as String? ?? 'on',
      cacheTypeK: json['cache_type_k'] as String? ?? 'q8_0',
      cacheTypeV: json['cache_type_v'] as String? ?? 'q8_0',
      parallel: json['parallel'] as int? ?? 1,
      host: json['host'] as String? ?? '127.0.0.1',
      port: json['port']?.toString() ?? '8080',
      mlock: json['mlock'] as bool? ?? false,
      extraArgs: json['extra_args'] as String? ?? '',
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      modifiedAt: json['modified_at'] != null
          ? DateTime.tryParse(json['modified_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
