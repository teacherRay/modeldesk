import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../controllers/hardware_controller.dart';

class HardwareStatusBar extends StatelessWidget {
  final HardwareController hardwareController;

  const HardwareStatusBar({
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

        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(top: BorderSide(color: AppTheme.border)),
          ),
          child: Row(
            children: [
              // Hardware indicator pulse dot
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hardwareController.isMonitoring ? AppTheme.success : AppTheme.textSubtle,
                  boxShadow: hardwareController.isMonitoring
                      ? [BoxShadow(color: AppTheme.success.withValues(alpha: 0.5), blurRadius: 4)]
                      : null,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'HARDWARE',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: AppTheme.textSubtle,
                ),
              ),
              const SizedBox(width: 14),

              // CPU Item
              _buildMetricPill(
                label: 'CPU',
                value: '${cpu.percent.toStringAsFixed(0)}%',
                percent: cpu.percent,
                color: _getUsageColor(cpu.percent),
                subValue: cpu.llamaCpuPercent != null && cpu.llamaCpuPercent! > 0.5
                    ? 'llama: ${cpu.llamaCpuPercent!.toStringAsFixed(0)}%'
                    : null,
              ),

              const SizedBox(width: 12),
              _buildDivider(),
              const SizedBox(width: 12),

              // RAM Item
              _buildMetricPill(
                label: 'RAM',
                value: '${ram.usedGbStr} / ${ram.totalGbStr} GB',
                percent: ram.percent,
                color: _getUsageColor(ram.percent),
                subValue: ram.llamaRamMb != null && ram.llamaRamMb! > 50
                    ? 'llama: ${(ram.llamaRamMb! / 1024).toStringAsFixed(1)}G'
                    : null,
              ),

              const SizedBox(width: 12),
              _buildDivider(),
              const SizedBox(width: 12),

              // GPU Item
              _buildMetricPill(
                label: 'GPU',
                value: '${gpu.utilPercent.toStringAsFixed(0)}%',
                percent: gpu.utilPercent,
                color: _getUsageColor(gpu.utilPercent),
                subValue: gpu.tempEdgeC != null ? '${gpu.tempEdgeC}°C' : null,
                subColor: _getTempColor(gpu.tempEdgeC),
              ),

              const SizedBox(width: 12),
              _buildDivider(),
              const SizedBox(width: 12),

              // VRAM Item
              _buildMetricPill(
                label: 'VRAM',
                value: '${gpu.vramUsedGbStr} / ${gpu.vramTotalGbStr} GB',
                percent: gpu.vramPercent,
                color: _getUsageColor(gpu.vramPercent),
                subValue: '${gpu.vramPercent.toStringAsFixed(0)}%',
              ),

              const Spacer(),

              // GPU Model Name Tag
              if (gpu.name.isNotEmpty && gpu.name != 'GPU')
                Text(
                  gpu.name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSubtle,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetricPill({
    required String label,
    required String value,
    required double percent,
    required Color color,
    String? subValue,
    Color? subColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(width: 6),
        // Mini progress bar
        Container(
          width: 36,
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
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Consolas',
          ),
        ),
        if (subValue != null) ...[
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.bgHover,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              subValue,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: subColor ?? AppTheme.textSubtle,
                fontFamily: 'Consolas',
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 14,
      color: AppTheme.border,
    );
  }
}
