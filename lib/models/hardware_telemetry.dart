class CpuTelemetry {
  final double percent;
  final int logicalCores;
  final String clockGhz;
  final double? llamaCpuPercent;

  const CpuTelemetry({
    required this.percent,
    required this.logicalCores,
    required this.clockGhz,
    this.llamaCpuPercent,
  });

  factory CpuTelemetry.empty() {
    return const CpuTelemetry(
      percent: 0.0,
      logicalCores: 1,
      clockGhz: 'Auto',
    );
  }
}

class RamTelemetry {
  final int usedBytes;
  final int totalBytes;
  final int freeBytes;
  final double percent;
  final int? llamaRamBytes;

  const RamTelemetry({
    required this.usedBytes,
    required this.totalBytes,
    required this.freeBytes,
    required this.percent,
    this.llamaRamBytes,
  });

  double get usedGb => usedBytes / (1024 * 1024 * 1024);
  double get totalGb => totalBytes / (1024 * 1024 * 1024);
  double get freeGb => freeBytes / (1024 * 1024 * 1024);
  double? get llamaRamMb => llamaRamBytes != null ? (llamaRamBytes! / (1024 * 1024)) : null;

  String get usedGbStr => usedGb.toStringAsFixed(1);
  String get totalGbStr => totalGb.toStringAsFixed(1);
  String get percentStr => '${percent.toStringAsFixed(0)}%';
  String get llamaRamMbStr => llamaRamMb != null ? '${llamaRamMb!.toStringAsFixed(0)} MB' : '';

  factory RamTelemetry.empty() {
    return const RamTelemetry(
      usedBytes: 0,
      totalBytes: 1,
      freeBytes: 1,
      percent: 0.0,
    );
  }
}

class GpuTelemetry {
  final String name;
  final double utilPercent;
  final int dedicatedVramUsedBytes;
  final int dedicatedVramTotalBytes;
  final double vramPercent;
  final int? tempEdgeC;
  final int? tempHotspotC;
  final int? tempMemC;
  final int? fanSpeed;
  final int? powerWatts;
  final int? gfxClockMhz;
  final int? memClockMhz;
  final bool isAdlAvailable;
  final bool isNvmlAvailable;

  const GpuTelemetry({
    required this.name,
    required this.utilPercent,
    required this.dedicatedVramUsedBytes,
    required this.dedicatedVramTotalBytes,
    required this.vramPercent,
    this.tempEdgeC,
    this.tempHotspotC,
    this.tempMemC,
    this.fanSpeed,
    this.powerWatts,
    this.gfxClockMhz,
    this.memClockMhz,
    this.isAdlAvailable = false,
    this.isNvmlAvailable = false,
  });

  double get vramUsedGb => dedicatedVramUsedBytes / (1024 * 1024 * 1024);
  double get vramTotalGb => dedicatedVramTotalBytes / (1024 * 1024 * 1024);

  String get vramUsedGbStr => vramUsedGb.toStringAsFixed(2);
  String get vramTotalGbStr => vramTotalGb.toStringAsFixed(2);
  String get utilPercentStr => '${utilPercent.toStringAsFixed(0)}%';
  String get vramPercentStr => '${vramPercent.toStringAsFixed(0)}%';

  factory GpuTelemetry.empty() {
    return const GpuTelemetry(
      name: 'GPU',
      utilPercent: 0.0,
      dedicatedVramUsedBytes: 0,
      dedicatedVramTotalBytes: 1,
      vramPercent: 0.0,
    );
  }
}

class HardwareTelemetry {
  final DateTime timestamp;
  final CpuTelemetry cpu;
  final RamTelemetry ram;
  final GpuTelemetry gpu;

  const HardwareTelemetry({
    required this.timestamp,
    required this.cpu,
    required this.ram,
    required this.gpu,
  });

  factory HardwareTelemetry.empty() {
    return HardwareTelemetry(
      timestamp: DateTime.now(),
      cpu: CpuTelemetry.empty(),
      ram: RamTelemetry.empty(),
      gpu: GpuTelemetry.empty(),
    );
  }
}
