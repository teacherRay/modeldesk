// ignore_for_file: deprecated_member_use, use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../controllers/settings_controller.dart';
import '../../controllers/server_controller.dart';
import '../../controllers/chat_controller.dart';
import '../../controllers/profile_controller.dart';

class SettingsTab extends StatelessWidget {
  final SettingsController settingsController;
  final ServerController serverController;
  final ChatController chatController;
  final ProfileController profileController;

  const SettingsTab({
    super.key,
    required this.settingsController,
    required this.serverController,
    required this.chatController,
    required this.profileController,
  });

  void _openGitHub() {
    if (Platform.isWindows) {
      try {
        Process.run('cmd', ['/c', 'start', 'https://github.com/teacherRay/modeldesk.git']);
      } catch (_) {}
    }
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text(title, style: const TextStyle(color: AppTheme.textMain, fontSize: 16)),
        content: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.textMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppTheme.danger : AppTheme.accent,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              onConfirm();
            },
            child: Text(
              confirmText,
              style: TextStyle(
                color: isDestructive ? Colors.white : const Color(0xFF11111B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.settings, color: AppTheme.accent, size: 24),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Application Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMain,
                            ),
                          ),
                          Text(
                            'Preferences, themes, telemetry polling, and application storage',
                            style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.bgInput,
                          foregroundColor: AppTheme.textMain,
                        ),
                        icon: const Icon(Icons.folder_open, size: 16),
                        label: const Text('Open AppData Folder', style: TextStyle(fontSize: 12)),
                        onPressed: () => settingsController.openAppDataFolder(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 1. Appearance & Theme Card
              _buildAppearanceCard(context),
              const SizedBox(height: 12),

              // 2. Hardware Telemetry Card
              _buildTelemetryCard(context),
              const SizedBox(height: 12),

              // 3. Automation & Server Defaults Card
              _buildServerPreferencesCard(context),
              const SizedBox(height: 12),

              // 4. Data Management & Maintenance Card
              _buildDataManagementCard(context),
              const SizedBox(height: 12),

              // 5. About & Publisher Card
              _buildAboutCard(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAppearanceCard(BuildContext context) {
    final currentTheme = settingsController.themeMode;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.palette_outlined, size: 18, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'APPEARANCE & THEMES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Select your preferred high-contrast dark desktop palette:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSubtle),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                _buildThemeTile(
                  title: 'Catppuccin Mocha',
                  subtitle: 'Modern Slate Dark',
                  modeKey: 'catppuccin',
                  isSelected: currentTheme == 'catppuccin',
                  accentColor: const Color(0xFF89B4FA),
                  bgColor: const Color(0xFF1E1E2E),
                ),
                const SizedBox(width: 12),
                _buildThemeTile(
                  title: 'Midnight AMOLED',
                  subtitle: 'True Pitch Black',
                  modeKey: 'midnight',
                  isSelected: currentTheme == 'midnight',
                  accentColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFF000000),
                ),
                const SizedBox(width: 12),
                _buildThemeTile(
                  title: 'Nord Polar',
                  subtitle: 'Arctic Frost Blue',
                  modeKey: 'nord',
                  isSelected: currentTheme == 'nord',
                  accentColor: const Color(0xFF88C0D0),
                  bgColor: const Color(0xFF2E3440),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required String title,
    required String subtitle,
    required String modeKey,
    required bool isSelected,
    required Color accentColor,
    required Color bgColor,
  }) {
    return Expanded(
      child: InkWell(
        onTap: () => settingsController.setThemeMode(modeKey),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? accentColor : AppTheme.border,
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: AppTheme.textSubtle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryCard(BuildContext context) {
    final interval = settingsController.telemetryIntervalMs;
    final showBar = settingsController.showHardwareBar;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.speed, size: 18, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'HARDWARE MONITORING & REFRESH RATE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Telemetry Sampling Rate:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const Text(
                        'Controls how often CPU, RAM, DirectX DXGI VRAM, and AMD ADL sensors are queried via FFI.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int>(
                    value: interval,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 1000, child: Text('1.0s (Fast / High Responsiveness)')),
                      DropdownMenuItem(value: 1500, child: Text('1.5s (Standard Default)')),
                      DropdownMenuItem(value: 3000, child: Text('3.0s (Power Saver)')),
                      DropdownMenuItem(value: 0, child: Text('Paused (Telemetry Disabled)')),
                    ],
                    onChanged: (val) {
                      if (val != null) settingsController.setTelemetryInterval(val);
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show Bottom Hardware Status Bar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Displays compact live CPU, RAM, GPU, and VRAM pill indicators anchored at the bottom of the window.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
              ),
              value: showBar,
              activeColor: AppTheme.accent,
              onChanged: (val) => settingsController.setShowHardwareBar(val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerPreferencesCard(BuildContext context) {
    final autostart = settingsController.autostartServer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.tune, size: 18, color: AppTheme.accent),
                SizedBox(width: 8),
                Text(
                  'SERVER & AUTOMATION PREFERENCES',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.accent, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 14),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Autostart Server on App Launch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: const Text(
                'Automatically launch llama-server in the background using active model and profile when ModelDesk opens.',
                style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
              ),
              value: autostart,
              activeColor: AppTheme.accent,
              onChanged: (val) => settingsController.setAutostartServer(val),
            ),
            const Divider(height: 20),

            Row(
              children: [
                const Text('Local Engine Endpoint: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppTheme.bgInput, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    serverController.config.baseUrl,
                    style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', color: AppTheme.accent),
                  ),
                ),
                const SizedBox(width: 14),
                const Text('Executable: ', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: AppTheme.bgInput, borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      serverController.config.llamaBin,
                      style: const TextStyle(fontSize: 11, fontFamily: 'Consolas', color: AppTheme.textSubtle),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services, size: 18, color: AppTheme.danger),
                SizedBox(width: 8),
                Text(
                  'DATA MANAGEMENT & MAINTENANCE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.danger, letterSpacing: 0.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Reset local cache and files stored in your Windows user profile:',
              style: TextStyle(fontSize: 12, color: AppTheme.textSubtle),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                // Clear Conversations
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
                  icon: const Icon(Icons.delete_sweep, size: 16),
                  label: const Text('Clear Chat History'),
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Clear Chat History?',
                    message: 'This will delete all saved conversation JSON files. This action cannot be undone.',
                    confirmText: 'Delete All Chats',
                    isDestructive: true,
                    onConfirm: () async {
                      await settingsController.clearAllConversations(chatController);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Chat history cleared.')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Reset Server Config
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.warning),
                  icon: const Icon(Icons.restart_alt, size: 16),
                  label: const Text('Reset Server Config'),
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Reset Server Settings?',
                    message: 'This will restore all server parameters, host, and port to default recommended values.',
                    confirmText: 'Reset to Defaults',
                    onConfirm: () async {
                      await settingsController.resetServerConfig(serverController);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Server configuration reset to default.')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),

                // Reset Profiles
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppTheme.accent),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Restore Starter Profiles'),
                  onPressed: () => _confirmAction(
                    context,
                    title: 'Restore Starter Profiles?',
                    message: 'This will re-seed the default starter profiles (Max GPU Offload, 32K Context, CPU Fallback).',
                    confirmText: 'Restore Profiles',
                    onConfirm: () async {
                      await settingsController.resetProfiles(profileController);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Default starter profiles restored.')),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🦙', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ModelDesk',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textMain),
                    ),
                    Text(
                      'Version 1.0.0 (Release) · Native Local AI Desktop Interface',
                      style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
                    ),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: const Color(0xFF11111B),
                  ),
                  icon: const Icon(Icons.code, size: 16),
                  label: const Text('GitHub Repository', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: _openGitHub,
                ),
              ],
            ),
            const Divider(height: 24),

            const Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: AppTheme.success),
                SizedBox(width: 8),
                Text(
                  'Local Inference Philosophy',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.success),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'ModelDesk operates 100% offline. No telemetry, user tracking, or cloud pings are performed. '
              'All prompts, weights, and conversations remain strictly on your local machine.',
              style: TextStyle(fontSize: 11, color: AppTheme.textSubtle),
            ),
            const SizedBox(height: 12),

            const Text(
              'Developed and published by Southern Apps. Licensed under the MIT License.',
              style: TextStyle(fontSize: 10, color: AppTheme.textSubtle),
            ),
          ],
        ),
      ),
    );
  }
}
