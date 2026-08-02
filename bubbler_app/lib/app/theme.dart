import 'package:flutter/material.dart';

/// Brand colors and Material theme for Bubbler.
///
/// Matches the blue/cyan gradient language used on the SwiftUI auth screens.
abstract final class BubblerTheme {
  static const Color blue = Color(0xFF1565C0);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color deepBlue = Color(0xFF0D47A1);

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF00ACC1),
      Color(0xFF1565C0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: blue,
      brightness: Brightness.light,
      primary: blue,
      secondary: cyan,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: deepBlue,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.iOS).white.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
