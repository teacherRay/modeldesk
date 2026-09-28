// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import '../models/server_config.dart';
import '../models/gguf_model.dart';
import '../services/process_service.dart';
import '../services/llama_client.dart';
import '../services/storage_service.dart';
import '../services/model_scanner_service.dart';

class ServerController extends ChangeNotifier {
  final ProcessService _processService;
  final LlamaClient _llamaClient;
  final StorageService _storageService;
  late final ModelScannerService _scanner;

  ServerConfig _config = ServerConfig.knownWorkingDefault();
  final List<String> _consoleLogs = [];
  Timer? _healthPoller;
  StreamSubscription? _logSub;
  StreamSubscription? _statusSub;
  bool _isScanningModels = false;

  ServerController({
    required ProcessService processService,
    required LlamaClient llamaClient,
    required StorageService storageService,
    ModelScannerService? scanner,
  })  : _processService = processService,
        _llamaClient = llamaClient,
        _storageService = storageService {
    _scanner = scanner ?? ModelScannerService();
    _init();
  }

  ServerConfig get config => _config;
  ServerStatus get status => _processService.status;
  bool get isRunning => status == ServerStatus.running;
  bool get isStarting => status == ServerStatus.starting;
  bool get isStopped => status == ServerStatus.stopped || status == ServerStatus.error;
  int? get serverPid => _processService.pid;
  List<String> get consoleLogs => List.unmodifiable(_consoleLogs);
  bool get isScanningModels => _isScanningModels;

  List<GgufModelInfo> get availableModels => _scanner.models;
  List<GgufModelInfo> get availableMmprojs => _scanner.mmprojs;

  Future<void> _init() async {
    _config = await _storageService.loadServerConfig();

    for (final dir in _config.customModelDirs) {
      _scanner.addDirectory(dir);
    }

    _logSub = _processService.logStream.listen((log) {
      _consoleLogs.add(log);
      if (_consoleLogs.length > 2000) {
        _consoleLogs.removeAt(0);
      }
      notifyListeners();
    });

    _statusSub = _processService.statusStream.listen((newStatus) {
      if (newStatus == ServerStatus.running) {
        _stopHealthPoller();
      } else if (newStatus == ServerStatus.stopped || newStatus == ServerStatus.error) {
        _stopHealthPoller();
      }
      notifyListeners();
    });

    final isAlreadyRunning = await _llamaClient.checkHealth(_config.baseUrl);
    if (isAlreadyRunning) {
      await _processService.markAsRunning();
    }

    await rescanModels();
    notifyListeners();
  }

  // --- Model Scanner Actions ---

  Future<void> rescanModels() async {
    _isScanningModels = true;
    notifyListeners();

    await _scanner.rescan();

    // If config has no model or model not found, select first available
    if (_config.modelPath.isEmpty && _scanner.models.isNotEmpty) {
      setModelPath(_scanner.models.first.path);
    }

    _isScanningModels = false;
    notifyListeners();
  }

  Future<void> browseModelFile() async {
    final picked = await _scanner.pickModelFile();
    if (picked != null) {
      setModelPath(picked);
    }
  }

  Future<void> browseMmprojFile() async {
    final picked = await _scanner.pickMmprojFile();
    if (picked != null) {
      setMmprojPath(picked);
    }
  }

  Future<void> addCustomModelFolder() async {
    final pickedDir = await _scanner.pickCustomDirectory();
    if (pickedDir != null) {
      if (!_config.customModelDirs.contains(pickedDir)) {
        _config.customModelDirs.add(pickedDir);
        _saveConfig();
      }
      await rescanModels();
    }
  }

  Future<void> removeCustomModelFolder(String dir) async {
    final norm = p.normalize(dir);
    if (_config.customModelDirs.contains(norm)) {
      _config.customModelDirs.remove(norm);
      _scanner.removeDirectory(norm);
      _saveConfig();
      await rescanModels();
    }
  }

  Future<void> browseLlamaBin() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Select llama / llama-server Executable',
      type: FileType.custom,
      allowedExtensions: ['exe'],
    );
    if (result.isNotEmpty && result.first.path != null) {
      setLlamaBin(p.normalize(result.first.path!));
    }
  }

  // --- Parameter Modifiers ---

  void setModelPath(String path) {
    final norm = p.normalize(path);
    _config.modelPath = norm;

    // Auto-detect matching mmproj if present in the same directory
    final matchingMm = _scanner.findMatchingMmproj(norm);
    if (matchingMm != null && _config.mmprojPath.isEmpty) {
      _config.mmprojPath = matchingMm;
    }

    _saveConfig();
  }

  void setMmprojPath(String path) {
    _config.mmprojPath = path.isEmpty ? '' : p.normalize(path);
    _saveConfig();
  }

  void clearMmproj() {
    _config.mmprojPath = '';
    _saveConfig();
  }

  void setGpuLayers(int layers) {
    _config.nGpuLayers = layers;
    _saveConfig();
  }

  void setContextSize(String ctx) {
    _config.ctxSize = ctx.trim();
    _saveConfig();
  }

  void setThreads(int threads) {
    _config.threads = threads;
    _saveConfig();
  }

  void setFlashAttention(String fa) {
    _config.flashAttn = fa;
    _saveConfig();
  }

  void setCacheTypeK(String ctk) {
    _config.cacheTypeK = ctk;
    _saveConfig();
  }

  void setCacheTypeV(String ctv) {
    _config.cacheTypeV = ctv;
    _saveConfig();
  }

  void setParallel(int np) {
    _config.parallel = np;
    _saveConfig();
  }

  void setHost(String host) {
    _config.host = host.trim();
    _saveConfig();
  }

  void setPort(String port) {
    _config.port = port.trim();
    _saveConfig();
  }

  void setMlock(bool mlock) {
    _config.mlock = mlock;
    _saveConfig();
  }

  void setExtraArgs(String extra) {
    _config.extraArgs = extra;
    _saveConfig();
  }

  void setLlamaBin(String bin) {
    _config.llamaBin = bin.trim();
    _saveConfig();
  }

  void updateConfig(ServerConfig newConfig) {
    _config = newConfig;
    _saveConfig();
  }

  void _saveConfig() {
    _storageService.saveServerConfig(_config);
    notifyListeners();
  }

  // --- Process Control ---

  Future<bool> startServer() async {
    if (isRunning || isStarting) return false;

    final started = await _processService.startServer(_config);
    if (!started) {
      notifyListeners();
      return false;
    }

    _startHealthPoller();
    notifyListeners();
    return true;
  }

  Future<void> stopServer() async {
    _stopHealthPoller();
    await _processService.stopServer();
    notifyListeners();
  }

  void _startHealthPoller() {
    _stopHealthPoller();
    var attempts = 0;
    const maxAttempts = 120;

    _healthPoller = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      attempts++;
      if (attempts > maxAttempts || !isStarting) {
        _stopHealthPoller();
        return;
      }

      final isHealthy = await _llamaClient.checkHealth(_config.baseUrl);
      if (isHealthy) {
        _stopHealthPoller();
        await _processService.markAsRunning();
        notifyListeners();
      }
    });
  }

  void _stopHealthPoller() {
    _healthPoller?.cancel();
    _healthPoller = null;
  }

  void clearLogs() {
    _consoleLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopHealthPoller();
    _logSub?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }
}
