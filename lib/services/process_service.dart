import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/server_config.dart';
import '../core/utils.dart';

enum ServerStatus {
  stopped,
  starting,
  running,
  stopping,
  error,
}

class ProcessService {
  Process? _process;
  ServerStatus _status = ServerStatus.stopped;
  final _logController = StreamController<String>.broadcast();
  final _statusController = StreamController<ServerStatus>.broadcast();
  
  Stream<String> get logStream => _logController.stream;
  Stream<ServerStatus> get statusStream => _statusController.stream;
  ServerStatus get status => _status;
  int? get pid => _process?.pid;
  bool get isRunning => _status == ServerStatus.running || _status == ServerStatus.starting;

  void _setStatus(ServerStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _addLog(String message) {
    final clean = AppUtils.stripAnsi(message);
    _logController.add(clean);
  }

  Future<bool> startServer(ServerConfig config) async {
    if (isRunning) {
      _addLog('[LAUNCHER] Server is already running or starting.');
      return false;
    }

    final binFile = File(config.llamaBin);
    if (!await binFile.exists()) {
      _setStatus(ServerStatus.error);
      _addLog('[ERROR] llama executable not found at: ${config.llamaBin}');
      return false;
    }

    final modelFile = File(config.modelPath);
    if (!await modelFile.exists()) {
      _setStatus(ServerStatus.error);
      _addLog('[ERROR] Model file not found at: ${config.modelPath}');
      return false;
    }

    if (config.mmprojPath.isNotEmpty) {
      final mmprojFile = File(config.mmprojPath);
      if (!await mmprojFile.exists()) {
        _setStatus(ServerStatus.error);
        _addLog('[ERROR] mmproj vision file not found at: ${config.mmprojPath}');
        return false;
      }
    }

    _setStatus(ServerStatus.starting);
    final args = config.buildCommandArgs();
    _addLog('=' * 60);
    _addLog('[LAUNCHER] Launching llama-server...');
    _addLog('[COMMAND] ${config.commandPreview}');
    _addLog('=' * 60);

    try {
      _process = await Process.start(
        config.llamaBin,
        args,
        runInShell: false,
        mode: ProcessStartMode.normal,
      );

      _addLog('[LAUNCHER] Process spawned with PID: ${_process!.pid}');

      // Stream stdout
      _process!.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.contains('HTTP server is listening') ||
            line.contains('all slots are ready')) {
          if (_status == ServerStatus.starting) {
            _setStatus(ServerStatus.running);
            _addLog('[LAUNCHER] Server is LIVE and listening at ${config.baseUrl}');
          }
        }
        _addLog(line);
      }, onError: (err) {
        _addLog('[ERROR stdout] $err');
      });

      // Stream stderr
      _process!.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.contains('HTTP server is listening') ||
            line.contains('all slots are ready')) {
          if (_status == ServerStatus.starting) {
            _setStatus(ServerStatus.running);
            _addLog('[LAUNCHER] Server is LIVE and listening at ${config.baseUrl}');
          }
        }
        _addLog(line);
      }, onError: (err) {
        _addLog('[ERROR stderr] $err');
      });

      // Handle process exit
      _process!.exitCode.then((code) {
        _addLog('[LAUNCHER] llama-server exited with code: $code');
        _process = null;
        if (_status != ServerStatus.stopping && _status != ServerStatus.stopped) {
          _setStatus(code == 0 ? ServerStatus.stopped : ServerStatus.error);
        } else {
          _setStatus(ServerStatus.stopped);
        }
      });

      return true;
    } catch (e) {
      _setStatus(ServerStatus.error);
      _addLog('[ERROR] Failed to start llama-server: $e');
      return false;
    }
  }

  Future<void> markAsRunning() async {
    if (_status == ServerStatus.starting) {
      _setStatus(ServerStatus.running);
    }
  }

  Future<void> stopServer() async {
    final currentPid = _process?.pid;
    _setStatus(ServerStatus.stopping);

    if (currentPid != null) {
      _addLog('[LAUNCHER] Stopping server process PID: $currentPid...');
      try {
        if (Platform.isWindows) {
          final result = await Process.run(
            'taskkill',
            ['/F', '/T', '/PID', currentPid.toString()],
          );
          _addLog('[LAUNCHER] Process tree terminated (exit ${result.exitCode})');
        } else {
          _process?.kill(ProcessSignal.sigterm);
        }
      } catch (e) {
        _addLog('[ERROR] Exception during process termination: $e');
      }
    } else if (Platform.isWindows) {
      // Reopened app fallback: terminate any active llama server
      _addLog('[LAUNCHER] Stopping active llama server process...');
      try {
        await Process.run('taskkill', ['/F', '/IM', 'llama.exe']);
        await Process.run('taskkill', ['/F', '/IM', 'llama-server.exe']);
        _addLog('[LAUNCHER] Active server processes terminated.');
      } catch (e) {
        _addLog('[ERROR] Exception during fallback process termination: $e');
      }
    }

    _process = null;
    _setStatus(ServerStatus.stopped);
  }

  void dispose() {
    _logController.close();
    _statusController.close();
  }
}
