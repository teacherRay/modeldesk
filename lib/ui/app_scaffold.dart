import 'dart:io';
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../controllers/chat_controller.dart';
import '../controllers/server_controller.dart';
import '../controllers/hardware_controller.dart';
import '../controllers/profile_controller.dart';
import 'package:flutter/services.dart';
import 'widgets/status_badge.dart';
import 'widgets/hardware_status_bar.dart';
import 'widgets/benchmark_runner_dialog.dart';
import 'tabs/chat_tab.dart';
import 'tabs/server_tab.dart';
import 'tabs/models_tab.dart';
import 'tabs/profiles_tab.dart';
import 'tabs/settings_tab.dart';
import '../controllers/settings_controller.dart';

class AppScaffold extends StatefulWidget {
  final ChatController chatController;
  final ServerController serverController;
  final HardwareController hardwareController;
  final ProfileController profileController;
  final SettingsController settingsController;

  const AppScaffold({
    super.key,
    required this.chatController,
    required this.serverController,
    required this.hardwareController,
    required this.profileController,
    required this.settingsController,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  void _openWebUi() {
    final url = widget.serverController.config.baseUrl;
    try {
      if (Platform.isWindows) {
        Process.run('cmd', ['/c', 'start', url]);
      }
    } catch (_) {}
  }

  void _openBenchmarkRunner() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BenchmarkRunnerDialog(
        serverController: widget.serverController,
        llamaClient: widget.serverController.llamaClient,
        hardwareMonitor: widget.hardwareController.monitorService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final srv = widget.serverController;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.keyB,
          control: true,
          shift: true,
        ): _openBenchmarkRunner,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(bottom: BorderSide(color: AppTheme.border)),
            ),
            child: Row(
              children: [
                // Title & Logo
                Row(
                  children: [
                    const Text('🦙', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ModelDesk',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMain,
                          ),
                        ),
                        Text(
                          'Local AI Engine by Southern Apps',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textSubtle,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 32),

                // Navigation Tabs
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 36,
                      constraints: const BoxConstraints(maxWidth: 540),
                      decoration: BoxDecoration(
                        color: AppTheme.bgInput,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: AppTheme.bgHover,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        labelColor: AppTheme.accent,
                        unselectedLabelColor: AppTheme.textMuted,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontSize: 13),
                        tabs: const [
                          Tab(text: 'Chat'),
                          Tab(text: 'Server'),
                          Tab(text: 'Models'),
                          Tab(text: 'Profiles'),
                          Tab(text: 'Settings'),
                        ],
                      ),
                    ),
                  ),
                ),

                // Right Status & Quick Controls
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    StatusBadge(
                      status: srv.status,
                      url: srv.isRunning ? srv.config.baseUrl : null,
                    ),
                    const SizedBox(width: 10),
                    if (srv.isRunning)
                      IconButton(
                        icon: const Icon(Icons.open_in_browser, size: 20, color: AppTheme.cyan),
                        tooltip: 'Open llama.cpp Web UI (Browser)',
                        onPressed: _openWebUi,
                      ),
                    const SizedBox(width: 6),
                    if (srv.isStopped)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.success,
                          foregroundColor: const Color(0xFF11111B),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.play_arrow, size: 16),
                        label: const Text('Start'),
                        onPressed: () => srv.startServer(),
                      )
                    else
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        icon: const Icon(Icons.stop, size: 16),
                        label: const Text('Stop'),
                        onPressed: srv.isStarting || srv.isRunning ? () => srv.stopServer() : null,
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Main Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 1. Native Chat Tab
                ChatTab(
                  chatController: widget.chatController,
                  serverController: widget.serverController,
                ),

                // 2. Server Control & Logs Tab
                ServerTab(
                  serverController: widget.serverController,
                  hardwareController: widget.hardwareController,
                  profileController: widget.profileController,
                ),

                // 3. Models Library Tab
                ModelsTab(
                  serverController: widget.serverController,
                  profileController: widget.profileController,
                  onNavigateToTab: (index) => _tabController.animateTo(index),
                ),

                // 4. Profiles Management Tab
                ProfilesTab(
                  serverController: widget.serverController,
                  profileController: widget.profileController,
                  onNavigateToTab: (index) => _tabController.animateTo(index),
                ),

                // 5. Settings Tab
                SettingsTab(
                  settingsController: widget.settingsController,
                  serverController: widget.serverController,
                  chatController: widget.chatController,
                  profileController: widget.profileController,
                ),
              ],
            ),
          ),

          // Bottom Hardware Status Bar (toggled by settings)
          if (widget.settingsController.showHardwareBar)
            HardwareStatusBar(hardwareController: widget.hardwareController),
        ],
      ),
    ),
    ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
