import '../core/utils.dart';

class GgufModelInfo {
  final String name;
  final String path;
  final int sizeBytes;
  final bool isVisionMmproj;

  GgufModelInfo({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.isVisionMmproj,
  });

  String get formattedSize => AppUtils.formatBytes(sizeBytes);

  String get displayName => '$name [$formattedSize]';

  String get architectureFamily {
    if (isVisionMmproj) return 'Vision Projector';
    final lower = name.toLowerCase();
    if (lower.contains('deepseek')) return 'DeepSeek';
    if (lower.contains('gemma')) return 'Gemma';
    if (lower.contains('qwen')) return 'Qwen';
    if (lower.contains('llama')) return 'Llama';
    if (lower.contains('mistral')) return 'Mistral';
    if (lower.contains('mixtral')) return 'Mixtral';
    if (lower.contains('phi')) return 'Phi';
    if (lower.contains('minicpm')) return 'MiniCPM';
    if (lower.contains('command')) return 'Command-R';
    if (lower.contains('starcoder')) return 'StarCoder';
    if (lower.contains('yi')) return 'Yi';
    return 'LLM';
  }

  String get quantization {
    final match = RegExp(
      r'([iqbIQB][0-9]+[_a-zA-Z0-9]*|f16|f32|bf16|q[0-9]_[0-9]|q[0-9]_[a-zA-Z]_[a-zA-Z0-9]+)',
      caseSensitive: false,
    ).allMatches(name);

    if (match.isNotEmpty) {
      return match.last.group(0)?.toUpperCase() ?? '';
    }
    return '';
  }

  String get parameterSize {
    final match = RegExp(r'([0-9]+(?:\.[0-9]+)?[bB])', caseSensitive: false).firstMatch(name);
    return match?.group(0)?.toUpperCase() ?? '';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GgufModelInfo &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
