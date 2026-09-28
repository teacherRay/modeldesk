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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GgufModelInfo &&
          runtimeType == other.runtimeType &&
          path == other.path;

  @override
  int get hashCode => path.hashCode;
}
