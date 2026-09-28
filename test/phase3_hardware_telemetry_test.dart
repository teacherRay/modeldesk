import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:llama_launcher_flutter/models/hardware_telemetry.dart';
import 'package:llama_launcher_flutter/services/hardware_monitor_service.dart';
import 'package:llama_launcher_flutter/controllers/hardware_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Phase 3: Hardware Telemetry Data Models', () {
    test('CpuTelemetry correctly holds and formats metrics', () {
      const cpu = CpuTelemetry(
        percent: 24.5,
        logicalCores: 12,
        clockGhz: '3.60 GHz',
        llamaCpuPercent: 8.2,
      );

      expect(cpu.percent, equals(24.5));
      expect(cpu.logicalCores, equals(12));
      expect(cpu.clockGhz, equals('3.60 GHz'));
      expect(cpu.llamaCpuPercent, equals(8.2));

      final empty = CpuTelemetry.empty();
      expect(empty.percent, equals(0.0));
      expect(empty.logicalCores, equals(1));
    });

    test('RamTelemetry computes accurate GB and string representations', () {
      final ram = RamTelemetry(
        usedBytes: 16 * 1024 * 1024 * 1024, // 16 GB
        totalBytes: 32 * 1024 * 1024 * 1024, // 32 GB
        freeBytes: 16 * 1024 * 1024 * 1024,
        percent: 50.0,
        llamaRamBytes: 4 * 1024 * 1024 * 1024, // 4 GB
      );

      expect(ram.usedGb, closeTo(16.0, 0.01));
      expect(ram.totalGb, closeTo(32.0, 0.01));
      expect(ram.freeGb, closeTo(16.0, 0.01));
      expect(ram.usedGbStr, equals('16.0'));
      expect(ram.totalGbStr, equals('32.0'));
      expect(ram.percentStr, equals('50%'));
      expect(ram.llamaRamMb, closeTo(4096.0, 0.01));
      expect(ram.llamaRamMbStr, equals('4096 MB'));
    });

    test('GpuTelemetry computes accurate VRAM GB and sensor attributes', () {
      const gpu = GpuTelemetry(
        name: 'AMD Radeon RX 9060 XT',
        utilPercent: 35.0,
        dedicatedVramUsedBytes: 4294967296, // 4 GB
        dedicatedVramTotalBytes: 17179869184, // 16 GB
        vramPercent: 25.0,
        tempEdgeC: 45,
        tempHotspotC: 62,
        powerWatts: 85,
        gfxClockMhz: 1800,
        isAdlAvailable: true,
      );

      expect(gpu.name, equals('AMD Radeon RX 9060 XT'));
      expect(gpu.utilPercent, equals(35.0));
      expect(gpu.vramUsedGb, closeTo(4.0, 0.01));
      expect(gpu.vramTotalGb, closeTo(16.0, 0.01));
      expect(gpu.vramUsedGbStr, equals('4.00'));
      expect(gpu.vramTotalGbStr, equals('16.00'));
      expect(gpu.utilPercentStr, equals('35%'));
      expect(gpu.vramPercentStr, equals('25%'));
      expect(gpu.tempEdgeC, equals(45));
      expect(gpu.tempHotspotC, equals(62));
      expect(gpu.powerWatts, equals(85));
      expect(gpu.gfxClockMhz, equals(1800));
      expect(gpu.isAdlAvailable, isTrue);
    });
  });

  group('Phase 3: Native HardwareMonitorService FFI', () {
    test('Queries Windows System metrics, DXGI, and ADL sensors', () {
      if (!Platform.isWindows) return;

      final service = HardwareMonitorService();

      expect(service.gpuName, isNotEmpty);
      expect(service.dedicatedVramTotalBytes, greaterThan(0));

      final sample = service.sample();
      expect(sample.timestamp, isNotNull);

      // CPU checks
      expect(sample.cpu.logicalCores, greaterThanOrEqualTo(1));
      expect(sample.cpu.percent, greaterThanOrEqualTo(0.0));
      expect(sample.cpu.percent, lessThanOrEqualTo(100.0));

      // RAM checks
      expect(sample.ram.totalBytes, greaterThan(1024 * 1024 * 1024)); // > 1 GB
      expect(sample.ram.usedBytes, greaterThan(0));
      expect(sample.ram.percent, greaterThan(0.0));
      expect(sample.ram.percent, lessThanOrEqualTo(100.0));

      // GPU & VRAM checks
      expect(sample.gpu.name, isNotEmpty);
      expect(sample.gpu.dedicatedVramTotalBytes, greaterThan(0));
      expect(sample.gpu.utilPercent, greaterThanOrEqualTo(0.0));
      expect(sample.gpu.utilPercent, lessThanOrEqualTo(100.0));

      service.dispose();
    });

    test('Telemetry polling stream emits periodic samples', () async {
      if (!Platform.isWindows) return;

      final service = HardwareMonitorService();
      final samples = <HardwareTelemetry>[];

      final sub = service.telemetryStream.listen(samples.add);
      service.startSampling(intervalMs: 100);

      // Wait for at least 2 samples
      await Future.delayed(const Duration(milliseconds: 350));

      service.stopSampling();
      await sub.cancel();
      service.dispose();

      expect(samples.length, greaterThanOrEqualTo(2));
      expect(samples.first.ram.totalBytes, greaterThan(0));
    });
  });

  group('Phase 3: HardwareController State Management', () {
    test('Controls polling lifecycle and notifies listeners', () async {
      final controller = HardwareController();
      int updateCount = 0;

      controller.addListener(() => updateCount++);

      expect(controller.isMonitoring, isTrue);
      expect(controller.telemetry, isNotNull);

      controller.sampleOnce();
      expect(updateCount, greaterThanOrEqualTo(1));

      controller.stop();
      expect(controller.isMonitoring, isFalse);

      controller.start(intervalMs: 1500);
      expect(controller.isMonitoring, isTrue);

      controller.dispose();
    });
  });
}
