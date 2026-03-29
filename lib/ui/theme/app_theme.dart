import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Тема приложения
class AppTheme {
  // Цветовая палитра
  static const Color primaryColor = Color(0xFF2196F3);
  static const Color secondaryColor = Color(0xFF03DAC6);
  static const Color errorColor = Color(0xFFB00020);
  
  // Цвета статусов
  static const Color statusDirect = Color(0xFF4CAF50);
  static const Color statusMeshRelay = Color(0xFFFFC107);
  static const Color statusPending = Color(0xFF9E9E9E);
  static const Color statusDisconnected = Color(0xFFF44336);
  
  // Светлая тема
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
    ),
    textTheme: GoogleFonts.robotoTextTheme(),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),
  );
  
  // Темная тема
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
    ),
    textTheme: GoogleFonts.robotoTextTheme(
      ThemeData.dark().textTheme,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      filled: true,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      elevation: 4,
    ),
  );
}

/// Утилиты для работы с цветами статусов
class StatusColors {
  static Color getColor(String status) {
    switch (status) {
      case 'direct':
        return AppTheme.statusDirect;
      case 'mesh_relay':
        return AppTheme.statusMeshRelay;
      case 'pending':
        return AppTheme.statusPending;
      case 'disconnected':
        return AppTheme.statusDisconnected;
      default:
        return AppTheme.statusPending;
    }
  }
  
  static Color fromInt(int value) {
    return Color(value | 0xFF000000);
  }
}
