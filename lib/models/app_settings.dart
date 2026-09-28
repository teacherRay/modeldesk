class AppSettings {
  final String themeMode; // 'catppuccin', 'midnight', 'nord'
  final int telemetryIntervalMs; // 1000, 1500, 3000, 0 (disabled)
  final bool autostartServer;
  final bool showHardwareBar;
  final bool enableSounds;

  const AppSettings({
    this.themeMode = 'catppuccin',
    this.telemetryIntervalMs = 1500,
    this.autostartServer = false,
    this.showHardwareBar = true,
    this.enableSounds = false,
  });

  AppSettings copyWith({
    String? themeMode,
    int? telemetryIntervalMs,
    bool? autostartServer,
    bool? showHardwareBar,
    bool? enableSounds,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      telemetryIntervalMs: telemetryIntervalMs ?? this.telemetryIntervalMs,
      autostartServer: autostartServer ?? this.autostartServer,
      showHardwareBar: showHardwareBar ?? this.showHardwareBar,
      enableSounds: enableSounds ?? this.enableSounds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'theme_mode': themeMode,
      'telemetry_interval_ms': telemetryIntervalMs,
      'autostart_server': autostartServer,
      'show_hardware_bar': showHardwareBar,
      'enable_sounds': enableSounds,
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      themeMode: json['theme_mode'] as String? ?? 'catppuccin',
      telemetryIntervalMs: json['telemetry_interval_ms'] as int? ?? 1500,
      autostartServer: json['autostart_server'] as bool? ?? false,
      showHardwareBar: json['show_hardware_bar'] as bool? ?? true,
      enableSounds: json['enable_sounds'] as bool? ?? false,
    );
  }

  factory AppSettings.defaultSettings() => const AppSettings();
}
