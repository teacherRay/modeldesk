import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../controllers/server_controller.dart';
import '../widgets/status_badge.dart';

class ServerTab extends StatefulWidget {
  final ServerController serverController;

  const ServerTab({super.key, required this.serverController});

  @override
  State<ServerTab> createState() => _ServerTabState();
}

class _ServerTabState extends State<ServerTab> {
  final ScrollController _logScrollController = ScrollController();
  bool _autoScroll = true;

  @override
  Widget build(BuildContext context) {
    final srv = widget.serverController;
    final config = srv.config;

    // Auto-scroll logs to bottom if enabled
    if (_autoScroll && _logScrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_logScrollController.hasClients) {
          _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control Bar: Start/Stop & Status
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                StatusBadge(
                  status: srv.status,
                  url: srv.isRunning ? config.baseUrl : null,
                ),
                const Spacer(),
                if (srv.isStopped)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      foregroundColor: const Color(0xFF11111B),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.play_arrow, size: 20),
                    label: const Text('Start Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () => srv.startServer(),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.danger,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.stop, size: 20),
                    label: const Text('Stop Server', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: srv.isStarting || srv.isRunning
                        ? () => srv.stopServer()
                        : null,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Command Preview Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'COMMAND PREVIEW',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                        letterSpacing: 0.5,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.bgCardLight,
                        foregroundColor: AppTheme.textMain,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      icon: const Icon(Icons.copy, size: 13),
                      label: const Text('Copy Command'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: config.commandPreview));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Command copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.bgInput,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    config.commandPreview,
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: AppTheme.cyan,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Live Server Logs Card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SERVER CONSOLE OUTPUT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accent,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Row(
                        children: [
                          Row(
                            children: [
                              Checkbox(
                                value: _autoScroll,
                                activeColor: AppTheme.accent,
                                onChanged: (v) => setState(() => _autoScroll = v ?? true),
                              ),
                              const Text('Autoscroll', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            ],
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.bgCardLight,
                              foregroundColor: AppTheme.textMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              textStyle: const TextStyle(fontSize: 11),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            onPressed: () => srv.clearLogs(),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF11111B),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: srv.consoleLogs.isEmpty
                          ? const Center(
                              child: Text(
                                'No console output yet. Click "Start Server" to begin.',
                                style: TextStyle(color: AppTheme.textSubtle, fontSize: 12),
                              ),
                            )
                          : ListView.builder(
                              controller: _logScrollController,
                              itemCount: srv.consoleLogs.length,
                              itemBuilder: (context, index) {
                                final logLine = srv.consoleLogs[index];
                                Color lineCol = AppTheme.textMain;
                                if (logLine.contains('[ERROR') || logLine.contains('error')) {
                                  lineCol = AppTheme.danger;
                                } else if (logLine.contains('[LAUNCHER]') || logLine.contains('HTTP server')) {
                                  lineCol = AppTheme.accent;
                                } else if (logLine.contains('all slots are ready') || logLine.contains('LIVE')) {
                                  lineCol = AppTheme.success;
                                }
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 1.0),
                                  child: SelectableText(
                                    logLine,
                                    style: TextStyle(
                                      fontFamily: 'Consolas',
                                      fontSize: 11.5,
                                      color: lineCol,
                                      height: 1.2,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logScrollController.dispose();
    super.dispose();
  }
}
