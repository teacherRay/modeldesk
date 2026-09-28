// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/server_config.dart';
import '../services/process_service.dart';
import '../services/llama_client.dart';
import '../services/storage_service.dart';

class ServerController extends ChangeNotifier {
  final ProcessService _processService;
  final LlamaClient _llamaClient;
  final StorageService _storageService;

  ServerConfig _config = ServerConfig.knownWorkingDefault();
  final List<String> _consoleLogs = [];
  Timer? _healthPoller;
  StreamSubscription? _logSub;
  StreamSubscription? _statusSub;

  ServerController({
    required ProcessService processService,
    required LlamaClient llamaClient,
    required StorageService storageService,
  })  : _processService = processService,
        _llamaClient = llamaClient,
        _storageService = storageService {
    _init();
  }

  ServerConfig get config => _config;
  ServerStatus get status => _processService.status;
  bool get isRunning => status == ServerStatus.running;
  bool get isStarting => status == ServerStatus.starting;
  bool get isStopped => status == ServerStatus.stopped || status == ServerStatus.error;
  List<String> get consoleLogs => List.unmodifiable(_consoleLogs);

  Future<void> _init() async {
    _config = await _storageService.loadServerConfig();

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

    // Check if server was already running from a previous session
    final isAlreadyRunning = await _llamaClient.checkHealth(_config.baseUrl);
    if (isAlreadyRunning) {
      await _processService.markAsRunning();
    }

    notifyListeners();
  }

  void updateConfig(ServerConfig newConfig) {
    _config = newConfig;
    _storageService.saveServerConfig(_config);
    notifyListeners();
  }

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
    const maxAttempts = 120; // Up to 60 seconds

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
