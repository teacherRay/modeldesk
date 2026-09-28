// ignore_for_file: prefer_initializing_formals
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/app_settings.dart';
import '../models/server_config.dart';
import '../services/storage_service.dart';
import 'hardware_controller.dart';
import 'server_controller.dart';
import 'profile_controller.dart';
import 'chat_controller.dart';

class SettingsController extends ChangeNotifier {
  final StorageService _storageService;
  HardwareController? _hardwareController;
  AppSettings _settings = AppSettings.defaultSettings();
  bool _isLoaded = false;

  SettingsController({
    required StorageService storageService,
    HardwareController? hardwareController,
  })  : _storageService = storageService,
        _hardwareController = hardwareController {
    _load();
  }

  Future<void> init() async {
    await _load();
  }

  AppSettings get settings => _settings;
  String get themeMode => _settings.themeMode;
  int get telemetryIntervalMs => _settings.telemetryIntervalMs;
  bool get autostartServer => _settings.autostartServer;
  bool get showHardwareBar => _settings.showHardwareBar;
  bool get isLoaded => _isLoaded;
  String get appDataPath => _storageService.appDataPath;

  void attachHardwareController(HardwareController hardware) {
    _hardwareController = hardware;
    _applyHardwareSettings();
  }

  Future<void> _load() async {
    _settings = await _storageService.loadAppSettings();
    _isLoaded = true;
    _applyHardwareSettings();
    notifyListeners();
  }

  void _applyHardwareSettings() {
    if (_hardwareController != null) {
      if (_settings.telemetryIntervalMs == 0) {
        _hardwareController!.stop();
      } else {
        _hardwareController!.start(intervalMs: _settings.telemetryIntervalMs);
      }
    }
  }

  Future<void> setThemeMode(String mode) async {
    if (_settings.themeMode == mode) return;
    _settings = _settings.copyWith(themeMode: mode);
    await _storageService.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> setTelemetryInterval(int intervalMs) async {
    if (_settings.telemetryIntervalMs == intervalMs) return;
    _settings = _settings.copyWith(telemetryIntervalMs: intervalMs);
    await _storageService.saveAppSettings(_settings);
    _applyHardwareSettings();
    notifyListeners();
  }

  Future<void> setAutostartServer(bool autostart) async {
    if (_settings.autostartServer == autostart) return;
    _settings = _settings.copyWith(autostartServer: autostart);
    await _storageService.saveAppSettings(_settings);
    notifyListeners();
  }

  Future<void> setShowHardwareBar(bool show) async {
    if (_settings.showHardwareBar == show) return;
    _settings = _settings.copyWith(showHardwareBar: show);
    await _storageService.saveAppSettings(_settings);
    notifyListeners();
  }

  // --- Maintenance Operations ---

  Future<void> clearAllConversations(ChatController chatController) async {
    await _storageService.clearAllConversations();
    await chatController.reloadConversations();
    notifyListeners();
  }

  Future<void> resetServerConfig(ServerController serverController) async {
    await _storageService.resetServerConfig();
    serverController.updateConfig(ServerConfig.knownWorkingDefault());
    notifyListeners();
  }

  Future<void> resetProfiles(ProfileController profileController) async {
    await _storageService.resetProfiles();
    await profileController.loadProfiles();
    notifyListeners();
  }

  void openAppDataFolder() {
    if (Platform.isWindows && appDataPath.isNotEmpty) {
      try {
        Process.run('explorer.exe', [appDataPath]);
      } catch (_) {}
    }
  }
}
