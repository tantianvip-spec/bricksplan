import 'package:flutter/material.dart';

class AppTheme {
  static const Color legoRed = Color(0xFFED1C24);
  static const Color legoYellow = Color(0xFFFFD700);
  static const Color legoBlue = Color(0xFF0055BF);
  static const Color darkText = Color(0xFF333333);
  static const Color lightBg = Color(0xFFF8F8F8);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: legoRed,
        primary: legoRed,
        secondary: legoYellow,
        tertiary: legoBlue,
      ),
      scaffoldBackgroundColor: Colors.white,
      appBarTheme: const AppBarTheme(
        backgroundColor: legoRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
