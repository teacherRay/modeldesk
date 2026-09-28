import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import '../models/gguf_model.dart';

class ModelScannerService {
  final List<String> _scanDirectories = [];
  final List<GgufModelInfo> _models = [];
  final List<GgufModelInfo> _mmprojs = [];

  List<GgufModelInfo> get models => List.unmodifiable(_models);
  List<GgufModelInfo> get mmprojs => List.unmodifiable(_mmprojs);
  List<String> get scanDirectories => List.unmodifiable(_scanDirectories);

  ModelScannerService({List<String>? initialDirs, bool includeDefaultDirs = true}) {
    if (initialDirs != null) {
      _scanDirectories.addAll(initialDirs);
    }
    if (includeDefaultDirs) {
      _ensureDefaultDirectories();
    }
  }

  void _ensureDefaultDirectories() {
    final userProfile = Platform.environment['USERPROFILE'] ?? '';
    if (userProfile.isNotEmpty) {
      final defaultLm = p.join(userProfile, r'.lmstudio\models');
      final defaultModels = p.join(userProfile, 'models');
      if (!_scanDirectories.contains(defaultLm)) {
        _scanDirectories.add(defaultLm);
      }
      if (!_scanDirectories.contains(defaultModels)) {
        _scanDirectories.add(defaultModels);
      }
    }
  }

  void addDirectory(String path) {
    final norm = p.normalize(path);
    if (!_scanDirectories.contains(norm)) {
      _scanDirectories.add(norm);
    }
  }

  void removeDirectory(String path) {
    _scanDirectories.remove(p.normalize(path));
  }

  Future<void> rescan() async {
    _models.clear();
    _mmprojs.clear();

    for (final dirPath in _scanDirectories) {
      final dir = Directory(dirPath);
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(recursive: true, followLinks: false);
        for (final entity in entities) {
          if (entity is File && entity.path.toLowerCase().endsWith('.gguf')) {
            final fileName = p.basename(entity.path);
            final length = entity.lengthSync();
            final isVision = fileName.toLowerCase().startsWith('mmproj');

            final info = GgufModelInfo(
              name: fileName,
              path: p.normalize(entity.path),
              sizeBytes: length,
              isVisionMmproj: isVision,
            );

            if (isVision) {
              _mmprojs.add(info);
            } else {
              _models.add(info);
            }
          }
        }
      } catch (e) {
        // Silently skip inaccessible or permission-denied directories
      }
    }

    _models.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    _mmprojs.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String? findMatchingMmproj(String modelPath) {
    if (modelPath.isEmpty) return null;
    final modelDir = p.dirname(p.normalize(modelPath));
    for (final mm in _mmprojs) {
      if (p.dirname(p.normalize(mm.path)) == modelDir) {
        return mm.path;
      }
    }
    return null;
  }

  Future<String?> pickModelFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select GGUF Model File',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      final filePath = p.normalize(result.first.path!);
      final file = File(filePath);
      if (file.existsSync()) {
        final info = GgufModelInfo(
          name: p.basename(filePath),
          path: filePath,
          sizeBytes: file.lengthSync(),
          isVisionMmproj: p.basename(filePath).toLowerCase().startsWith('mmproj'),
        );
        if (!_models.contains(info) && !_mmprojs.contains(info)) {
          if (info.isVisionMmproj) {
            _mmprojs.insert(0, info);
          } else {
            _models.insert(0, info);
          }
        }
        return filePath;
      }
    }
    return null;
  }

  Future<String?> pickMmprojFile() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select Multimodal Projector (mmproj) File',
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );

    if (result.isNotEmpty && result.first.path != null) {
      final filePath = p.normalize(result.first.path!);
      final file = File(filePath);
      if (file.existsSync()) {
        final info = GgufModelInfo(
          name: p.basename(filePath),
          path: filePath,
          sizeBytes: file.lengthSync(),
          isVisionMmproj: true,
        );
        if (!_mmprojs.contains(info)) {
          _mmprojs.insert(0, info);
        }
        return filePath;
      }
    }
    return null;
  }

  Future<String?> pickCustomDirectory() async {
    final selectedDir = await FilePicker.getDirectoryPath(
      dialogTitle: 'Select Folder Containing GGUF Models',
    );
    if (selectedDir != null) {
      addDirectory(selectedDir);
      await rescan();
      return p.normalize(selectedDir);
    }
    return null;
  }
}
