// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/hardware_telemetry.dart';
import '../services/hardware_monitor_service.dart';

class HardwareController extends ChangeNotifier {
  final HardwareMonitorService _service;
  HardwareTelemetry _telemetry = HardwareTelemetry.empty();
  StreamSubscription<HardwareTelemetry>? _subscription;
  int? Function()? _pidProvider;
  bool _isMonitoring = false;

  HardwareController({
    HardwareMonitorService? service,
    int? Function()? pidProvider,
  })  : _service = service ?? HardwareMonitorService(),
        _pidProvider = pidProvider {
    _init();
  }

  HardwareTelemetry get telemetry => _telemetry;
  bool get isMonitoring => _isMonitoring;
  String get gpuName => _service.gpuName;
  bool get isAdlAvailable => _service.isAdlAvailable;

  void setPidProvider(int? Function() provider) {
    _pidProvider = provider;
  }

  void _init() {
    // Initial sample
    _telemetry = _service.sample(llamaPid: _pidProvider?.call());
    
    // Subscribe to stream
    _subscription = _service.telemetryStream.listen((data) {
      _telemetry = data;
      notifyListeners();
    });

    start();
  }

  void start({int intervalMs = 1500}) {
    if (_isMonitoring) return;
    _isMonitoring = true;
    _service.startSampling(
      intervalMs: intervalMs,
      pidProvider: _pidProvider,
    );
    notifyListeners();
  }

  void stop() {
    if (!_isMonitoring) return;
    _isMonitoring = false;
    _service.stopSampling();
    notifyListeners();
  }

  void sampleOnce() {
    _telemetry = _service.sample(llamaPid: _pidProvider?.call());
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    _subscription?.cancel();
    _service.dispose();
    super.dispose();
  }
}
