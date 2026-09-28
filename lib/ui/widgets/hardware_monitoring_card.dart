import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../controllers/hardware_controller.dart';
import '../../models/hardware_telemetry.dart';

class HardwareMonitoringCard extends StatelessWidget {
  final HardwareController hardwareController;

  const HardwareMonitoringCard({
    super.key,
    required this.hardwareController,
  });

  Color _getUsageColor(double percent) {
    if (percent < 60) return AppTheme.accent;
    if (percent < 85) return AppTheme.warning;
    return AppTheme.danger;
  }

  Color _getTempColor(int? tempC) {
    if (tempC == null) return AppTheme.textMuted;
    if (tempC < 65) return AppTheme.success;
    if (tempC < 80) return AppTheme.warning;
    return AppTheme.danger;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: hardwareController,
      builder: (context, _) {
        final telem = hardwareController.telemetry;
        final cpu = telem.cpu;
        final ram = telem.ram;
        final gpu = telem.gpu;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with GPU Name and Live Indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.speed, size: 20, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        const Text(
                          'Hardware Telemetry',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.bgInput,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Text(
                            gpu.name,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: hardwareController.isMonitoring
                                ? AppTheme.success
                                : AppTheme.textSubtle,
                            boxShadow: hardwareController.isMonitoring
                                ? [
                                    BoxShadow(
                                      color: AppTheme.success.withValues(alpha: 0.6),
                                      blurRadius: 4,
                                    )
                                  ]
                                : null,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          hardwareController.isMonitoring ? 'LIVE' : 'PAUSED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: hardwareController.isMonitoring
                                ? AppTheme.success
                                : AppTheme.textSubtle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 16, color: AppTheme.textMuted),
                          tooltip: 'Sample Hardware Now',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => hardwareController.sampleOnce(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4 Hardware Metric Tiles
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 650;
                    return GridView.count(
                      crossAxisCount: isNarrow ? 2 : 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: isNarrow ? 2.0 : 1.5,
                      children: [
                        // 1. CPU Tile
                        _buildMetricTile(
                          icon: Icons.memory,
                          title: 'CPU USAGE',
                          primaryValue: '${cpu.percent.toStringAsFixed(0)}%',
                          secondaryValue: '${cpu.logicalCores} Threads',
                          percent: cpu.percent,
                          color: _getUsageColor(cpu.percent),
                          subBadge: cpu.llamaCpuPercent != null && cpu.llamaCpuPercent! > 0.5
                              ? 'llama: ${cpu.llamaCpuPercent!.toStringAsFixed(1)}%'
                              : null,
                        ),

                        // 2. RAM Tile
                        _buildMetricTile(
                          icon: Icons.straighten,
                          title: 'SYSTEM RAM',
                          primaryValue: '${ram.usedGbStr} GB',
                          secondaryValue: 'of ${ram.totalGbStr} GB (${ram.percentStr})',
                          percent: ram.percent,
                          color: _getUsageColor(ram.percent),
                          subBadge: ram.llamaRamMb != null && ram.llamaRamMb! > 50
                              ? 'llama: ${(ram.llamaRamMb! / 1024).toStringAsFixed(1)} GB'
                              : null,
                        ),

                        // 3. GPU Tile
                        _buildGpuTile(gpu),

                        // 4. Dedicated VRAM Tile
                        _buildMetricTile(
                          icon: Icons.developer_board,
                          title: 'DEDICATED VRAM',
                          primaryValue: '${gpu.vramUsedGbStr} GB',
                          secondaryValue: 'of ${gpu.vramTotalGbStr} GB (${gpu.vramPercentStr})',
                          percent: gpu.vramPercent,
                          color: _getUsageColor(gpu.vramPercent),
                          subBadge: '${(gpu.vramTotalGb - gpu.vramUsedGb).toStringAsFixed(1)} GB Free',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String title,
    required String primaryValue,
    required String secondaryValue,
    required double percent,
    required Color color,
    String? subBadge,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              if (subBadge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.bgHover,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    subBadge,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accent,
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                primaryValue,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  secondaryValue,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSubtle,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.progressBg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percent / 100.0).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpuTile(GpuTelemetry gpu) {
    final color = _getUsageColor(gpu.utilPercent);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.bgInput,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.videogame_asset, size: 14, color: AppTheme.textMuted),
                  SizedBox(width: 6),
                  Text(
                    'GPU ENGINE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              // Thermal badge
              if (gpu.tempEdgeC != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.bgHover,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '${gpu.tempEdgeC}°C${gpu.tempHotspotC != null ? " / ${gpu.tempHotspotC}°C" : ""}',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: _getTempColor(gpu.tempEdgeC),
                      fontFamily: 'Consolas',
                    ),
                  ),
                ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${gpu.utilPercent.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontFamily: 'Consolas',
                ),
              ),
              const SizedBox(width: 6),
              if (gpu.powerWatts != null && gpu.powerWatts! > 0)
                Text(
                  '${gpu.powerWatts} W',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSubtle,
                    fontFamily: 'Consolas',
                  ),
                ),
              if (gpu.gfxClockMhz != null && gpu.gfxClockMhz! > 0) ...[
                const SizedBox(width: 4),
                Text(
                  '· ${gpu.gfxClockMhz} MHz',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSubtle,
                    fontFamily: 'Consolas',
                  ),
                ),
              ],
            ],
          ),
          // Progress bar
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.progressBg,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (gpu.utilPercent / 100.0).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
