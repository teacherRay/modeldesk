import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/process_service.dart';

class StatusBadge extends StatelessWidget {
  final ServerStatus status;
  final String? url;

  const StatusBadge({
    super.key,
    required this.status,
    this.url,
  });

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    String label;

    switch (status) {
      case ServerStatus.running:
        dotColor = AppTheme.success;
        label = url != null ? 'Running on $url' : 'Server Running';
        break;
      case ServerStatus.starting:
        dotColor = AppTheme.warning;
        label = 'Starting Server...';
        break;
      case ServerStatus.stopping:
        dotColor = AppTheme.warning;
        label = 'Stopping Server...';
        break;
      case ServerStatus.error:
        dotColor = AppTheme.danger;
        label = 'Server Error';
        break;
      case ServerStatus.stopped:
        dotColor = AppTheme.danger;
        label = 'Server Stopped';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: dotColor.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }
}
