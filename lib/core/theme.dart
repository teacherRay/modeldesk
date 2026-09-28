import 'package:flutter/material.dart';

class AppTheme {
  // Catppuccin Mocha / Modern Slate Dark Palette
  static const Color bgApp = Color(0xFF1E1E2E);
  static const Color bgSidebar = Color(0xFF181825);
  static const Color bgCard = Color(0xFF252538);
  static const Color bgCardLight = Color(0xFF2F2F45);
  static const Color bgInput = Color(0xFF313244);
  static const Color bgHover = Color(0xFF45475A);
  static const Color border = Color(0xFF45475A);

  static const Color textMain = Color(0xFFCDD6F4);
  static const Color textMuted = Color(0xFFA6ADC8);
  static const Color textSubtle = Color(0xFF6C7086);

  static const Color accent = Color(0xFF89B4FA);
  static const Color success = Color(0xFFA6E3A1);
  static const Color warning = Color(0xFFF9E2AF);
  static const Color danger = Color(0xFFF38BA8);
  static const Color cyan = Color(0xFF89DCEB);
  static const Color progressBg = Color(0xFF181825);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgApp,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        surface: bgCard,
        surfaceContainerHighest: bgCardLight,
        onSurface: textMain,
        error: danger,
      ),
      fontFamily: 'Segoe UI',
      dividerColor: border,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: bgInput,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: textSubtle, fontSize: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}
