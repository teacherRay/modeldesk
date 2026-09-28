// ignore_for_file: prefer_initializing_formals
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/model_profile.dart';
import '../models/server_config.dart';
import '../services/storage_service.dart';
import 'server_controller.dart';

class ProfileController extends ChangeNotifier {
  final StorageService _storageService;
  final List<ModelProfile> _profiles = [];
  ModelProfile? _activeProfile;
  bool _isLoading = false;

  ProfileController({required StorageService storageService})
      : _storageService = storageService {
    loadProfiles();
  }

  List<ModelProfile> get profiles => List.unmodifiable(_profiles);
  ModelProfile? get activeProfile => _activeProfile;
  bool get isLoading => _isLoading;

  Future<void> loadProfiles() async {
    _isLoading = true;
    notifyListeners();

    _profiles.clear();
    final loaded = await _storageService.loadAllProfiles();
    _profiles.addAll(loaded);

    // If active profile was selected, refresh reference
    if (_activeProfile != null) {
      final match = _profiles.where((p) => p.id == _activeProfile!.id);
      _activeProfile = match.isNotEmpty ? match.first : null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<ModelProfile> createProfile(ModelProfile profile) async {
    _profiles.insert(0, profile);
    await _storageService.saveProfile(profile);
    notifyListeners();
    return profile;
  }

  Future<ModelProfile> createFromCurrentConfig({
    required String name,
    String description = '',
    required ServerConfig config,
    bool isDefault = false,
  }) async {
    final profile = ModelProfile.fromServerConfig(
      name: name,
      description: description,
      config: config,
      isDefault: isDefault,
    );
    await createProfile(profile);
    _activeProfile = profile;
    notifyListeners();
    return profile;
  }

  Future<void> updateProfile(ModelProfile updated) async {
    final index = _profiles.indexWhere((p) => p.id == updated.id);
    if (index != -1) {
      _profiles[index] = updated;
      await _storageService.saveProfile(updated);
      if (_activeProfile?.id == updated.id) {
        _activeProfile = updated;
      }
      notifyListeners();
    }
  }

  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((p) => p.id == id);
    if (_activeProfile?.id == id) {
      _activeProfile = null;
    }
    await _storageService.deleteProfile(id);
    notifyListeners();
  }

  Future<ModelProfile> duplicateProfile(ModelProfile original) async {
    final clone = ModelProfile.create(
      name: '${original.name} (Copy)',
      description: original.description,
      modelPath: original.modelPath,
      mmprojPath: original.mmprojPath,
      nGpuLayers: original.nGpuLayers,
      threads: original.threads,
      ctxSize: original.ctxSize,
      flashAttn: original.flashAttn,
      cacheTypeK: original.cacheTypeK,
      cacheTypeV: original.cacheTypeV,
      parallel: original.parallel,
      host: original.host,
      port: original.port,
      mlock: original.mlock,
      extraArgs: original.extraArgs,
    );
    await createProfile(clone);
    return clone;
  }

  void applyProfile(ModelProfile profile, ServerController serverController) {
    _activeProfile = profile;
    final updated = profile.applyToConfig(serverController.config);
    serverController.updateConfig(updated);
    notifyListeners();
  }

  ModelProfile? findProfileForModel(String modelPath) {
    if (modelPath.isEmpty) return null;
    final targetBasename = p.basename(modelPath).toLowerCase();

    // 1. Exact path match
    for (final prof in _profiles) {
      if (prof.modelPath.isNotEmpty &&
          p.normalize(prof.modelPath).toLowerCase() == p.normalize(modelPath).toLowerCase()) {
        return prof;
      }
    }

    // 2. Basename match
    for (final prof in _profiles) {
      if (prof.modelFileName.isNotEmpty &&
          prof.modelFileName.toLowerCase() == targetBasename) {
        return prof;
      }
    }

    return null;
  }
}
