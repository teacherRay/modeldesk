import 'dart:io';
import 'package:path/path.dart' as p;

class ServerConfig {
  String llamaBin;
  String modelPath;
  String mmprojPath;
  int nGpuLayers;
  int threads;
  String ctxSize;
  String flashAttn;
  String cacheTypeK;
  String cacheTypeV;
  int parallel;
  String host;
  String port;
  bool mlock;
  String extraArgs;
  List<String> customModelDirs;

  ServerConfig({
    required this.llamaBin,
    required this.modelPath,
    this.mmprojPath = '',
    this.nGpuLayers = 18,
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
    List<String>? customModelDirs,
  }) : customModelDirs = customModelDirs ?? [];

  static String findDefaultLlamaBin() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final candidates = [
        p.join(userProfile, r'AppData\Local\Microsoft\WindowsApps\llama.EXE'),
        p.join(userProfile, r'AppData\Local\Microsoft\WindowsApps\llama.exe'),
        p.join(userProfile, r'AppData\Local\Programs\llama.cpp\llama.exe'),
        p.join(userProfile, r'AppData\Local\Programs\llama.cpp\llama-server.exe'),
        r'C:\Program Files\llama.cpp\llama.exe',
        r'C:\Program Files\llama.cpp\llama-server.exe',
      ];
      for (final c in candidates) {
        if (File(c).existsSync()) return c;
      }
    }
    return 'llama';
  }

  static String findDefaultModelPath() {
    if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final defaultDirs = [
        p.join(userProfile, r'.lmstudio\models'),
        p.join(userProfile, 'models'),
      ];
      for (final dirPath in defaultDirs) {
        final dir = Directory(dirPath);
        if (dir.existsSync()) {
          try {
            for (final entity in dir.listSync(recursive: true)) {
              if (entity is File &&
                  entity.path.toLowerCase().endsWith('.gguf') &&
                  !p.basename(entity.path).toLowerCase().startsWith('mmproj')) {
                return p.normalize(entity.path);
              }
            }
          } catch (_) {}
        }
      }
    }
    return '';
  }

  factory ServerConfig.knownWorkingDefault() {
    return ServerConfig(
      llamaBin: findDefaultLlamaBin(),
      modelPath: findDefaultModelPath(),
      mmprojPath: '',
      nGpuLayers: 18,
      threads: 6,
      ctxSize: '8192',
      flashAttn: 'on',
      cacheTypeK: 'q8_0',
      cacheTypeV: 'q8_0',
      parallel: 1,
      host: '127.0.0.1',
      port: '8080',
      mlock: false,
      extraArgs: '',
      customModelDirs: [],
    );
  }

  List<String> buildCommandArgs() {
    final args = <String>['serve'];

    if (modelPath.isNotEmpty) {
      args.addAll(['-m', modelPath]);
    }

    if (mmprojPath.isNotEmpty) {
      args.addAll(['--mmproj', mmprojPath]);
    }

    args.addAll(['-ngl', nGpuLayers.toString()]);
    args.addAll(['-t', threads.toString()]);

    if (ctxSize.isNotEmpty) {
      args.addAll(['-c', ctxSize]);
    }

    if (flashAttn.isNotEmpty) {
      args.addAll(['-fa', flashAttn]);
    }

    if (cacheTypeK.isNotEmpty) {
      args.addAll(['-ctk', cacheTypeK]);
    }

    if (cacheTypeV.isNotEmpty) {
      args.addAll(['-ctv', cacheTypeV]);
    }

    args.addAll(['-np', parallel.toString()]);

    if (mlock) {
      args.add('--mlock');
    }

    final h = host.trim().isEmpty ? '127.0.0.1' : host.trim();
    args.addAll(['--host', h]);

    final p = port.trim().isEmpty ? '8080' : port.trim();
    args.addAll(['--port', p]);

    if (extraArgs.trim().isNotEmpty) {
      final parts = extraArgs.trim().split(RegExp(r'\s+'));
      args.addAll(parts);
    }

    return args;
  }

  String get commandPreview {
    final args = [llamaBin, ...buildCommandArgs()];
    final formatted = args.map((a) {
      if (a.contains(' ') || a.contains(r'\')) {
        return '"$a"';
      }
      return a;
    }).join(' ');
    return formatted;
  }

  String get baseUrl {
    final h = host == '0.0.0.0' ? '127.0.0.1' : host;
    return 'http://$h:$port';
  }

  ServerConfig copyWith({
    String? llamaBin,
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
    List<String>? customModelDirs,
  }) {
    return ServerConfig(
      llamaBin: llamaBin ?? this.llamaBin,
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
      customModelDirs: customModelDirs ?? List.from(this.customModelDirs),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'llama_bin': llamaBin,
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
      'custom_model_dirs': customModelDirs,
    };
  }

  factory ServerConfig.fromJson(Map<String, dynamic> json) {
    return ServerConfig(
      llamaBin: json['llama_bin'] as String? ?? findDefaultLlamaBin(),
      modelPath: json['model_path'] as String? ?? findDefaultModelPath(),
      mmprojPath: json['mmproj_path'] as String? ?? '',
      nGpuLayers: json['n_gpu_layers'] as int? ?? 18,
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
      customModelDirs: (json['custom_model_dirs'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}
