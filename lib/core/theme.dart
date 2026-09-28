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

  static const Color midnightBg = Color(0xFF000000);
  static const Color midnightCard = Color(0xFF121212);
  static const Color midnightCardLight = Color(0xFF1A1A1A);
  static const Color midnightInput = Color(0xFF1E1E1E);
  static const Color midnightAccent = Color(0xFF10B981); // Emerald
  static const Color midnightBorder = Color(0xFF2A2A2A);

  static const Color nordBg = Color(0xFF2E3440);
  static const Color nordCard = Color(0xFF3B4252);
  static const Color nordCardLight = Color(0xFF434C5E);
  static const Color nordInput = Color(0xFF4C566A);
  static const Color nordAccent = Color(0xFF88C0D0); // Frost Blue
  static const Color nordBorder = Color(0xFF4C566A);

  static ThemeData get darkTheme => getTheme('catppuccin');

  static ThemeData getTheme(String mode) {
    switch (mode.toLowerCase()) {
      case 'midnight':
        return _buildTheme(
          bgApp: midnightBg,
          bgCard: midnightCard,
          bgCardLight: midnightCardLight,
          bgInput: midnightInput,
          accent: midnightAccent,
          border: midnightBorder,
        );
      case 'nord':
        return _buildTheme(
          bgApp: nordBg,
          bgCard: nordCard,
          bgCardLight: nordCardLight,
          bgInput: nordInput,
          accent: nordAccent,
          border: nordBorder,
        );
      case 'catppuccin':
      default:
        return _buildTheme(
          bgApp: bgApp,
          bgCard: bgCard,
          bgCardLight: bgCardLight,
          bgInput: bgInput,
          accent: accent,
          border: border,
        );
    }
  }

  static ThemeData _buildTheme({
    required Color bgApp,
    required Color bgCard,
    required Color bgCardLight,
    required Color bgInput,
    required Color accent,
    required Color border,
  }) {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgApp,
      colorScheme: ColorScheme.dark(
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
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
      ),
    );
  }
}
