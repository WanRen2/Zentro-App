import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static const _themeKey = 'zentro_theme';
  static final ThemeManager _instance = ThemeManager._internal();
  factory ThemeManager() => _instance;
  ThemeManager._internal();

  String _currentTheme = 'hacker';

  static const Map<String, Map<String, dynamic>> themes = {
    'hacker': {
      'name': 'Hacker',
      'accent': Color(0xFF00FF9C),
      'bg': Color(0xFF0A0A0A),
      'surface': Color(0xFF1A1A1A),
      'textPrimary': Color(0xFFE0E0E0),
      'textSecondary': Color(0xFF888888),
    },
    'cyberpunk': {
      'name': 'Cyberpunk',
      'accent': Color(0xFFFF00FF),
      'bg': Color(0xFF1A0A2E),
      'surface': Color(0xFF2A1040),
      'textPrimary': Color(0xFFFFFFFF),
      'textSecondary': Color(0xFFBBBBBB),
    },
    'midnight': {
      'name': 'Midnight',
      'accent': Color(0xFF4DA6FF),
      'bg': Color(0xFF0D1B2A),
      'surface': Color(0xFF1B2838),
      'textPrimary': Color(0xFFE0E8F0),
      'textSecondary': Color(0xFF8899AA),
    },
    'matrix': {
      'name': 'Matrix',
      'accent': Color(0xFF00FF00),
      'bg': Color(0xFF000000),
      'surface': Color(0xFF0A0A0A),
      'textPrimary': Color(0xFF00FF00),
      'textSecondary': Color(0xFF008800),
    },
    'sunset': {
      'name': 'Sunset',
      'accent': Color(0xFFFF6B35),
      'bg': Color(0xFF1A0A0A),
      'surface': Color(0xFF2A1515),
      'textPrimary': Color(0xFFF0E0E0),
      'textSecondary': Color(0xFFAA8888),
    },
    'ocean': {
      'name': 'Ocean',
      'accent': Color(0xFF00CED1),
      'bg': Color(0xFF0A1A2A),
      'surface': Color(0xFF152535),
      'textPrimary': Color(0xFFE0F0F8),
      'textSecondary': Color(0xFF88AABB),
    },
  };

  String get currentThemeKey => _currentTheme;
  Map<String, dynamic> get currentTheme => themes[_currentTheme]!;
  Color get accent => currentTheme['accent'] as Color;
  Color get bg => currentTheme['bg'] as Color;
  Color get surface => currentTheme['surface'] as Color;
  Color get textPrimary => currentTheme['textPrimary'] as Color;
  Color get textSecondary => currentTheme['textSecondary'] as Color;

  Future<void> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _currentTheme = prefs.getString(_themeKey) ?? 'hacker';
  }

  Future<void> setTheme(String themeKey) async {
    if (themes.containsKey(themeKey)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, themeKey);
      _currentTheme = themeKey;
    }
  }

  ThemeData getThemeData() {
    final theme = themes[_currentTheme]!;
    final accentColor = theme['accent'] as Color;
    final bgColor = theme['bg'] as Color;
    final surfaceColor = theme['surface'] as Color;
    final textPrimaryColor = theme['textPrimary'] as Color;
    final textSecondaryColor = theme['textSecondary'] as Color;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgColor,
      fontFamily: 'JetBrainsMono',
      colorScheme: ColorScheme.dark(
        primary: accentColor,
        secondary: accentColor.withValues(alpha: 0.8),
        surface: surfaceColor,
        error: const Color(0xFFFF4444),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: textPrimaryColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimaryColor),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: textSecondaryColor.withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: textSecondaryColor.withValues(alpha: 0.3),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: accentColor),
        ),
        hintStyle: TextStyle(
          fontFamily: 'JetBrainsMono',
          color: textSecondaryColor,
          fontSize: 14,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accentColor,
        foregroundColor: bgColor,
      ),
      dividerTheme: DividerThemeData(
        color: textSecondaryColor.withValues(alpha: 0.2),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        textColor: textPrimaryColor,
        iconColor: textSecondaryColor,
      ),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: textPrimaryColor, fontSize: 14),
        bodyMedium: TextStyle(color: textPrimaryColor, fontSize: 13),
        bodySmall: TextStyle(color: textSecondaryColor, fontSize: 12),
        labelLarge: TextStyle(color: textPrimaryColor, fontSize: 14),
        labelMedium: TextStyle(color: textSecondaryColor, fontSize: 12),
        titleMedium: TextStyle(
          color: textPrimaryColor,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: TextStyle(
          color: textPrimaryColor,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
