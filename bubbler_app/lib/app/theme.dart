import 'package:flutter/material.dart';

/// Brand colors and Material theme for Bubbler.
///
/// Matches the blue/cyan gradient language used on the SwiftUI auth screens
/// and shared glassmorphism cards (post card, banners, preference editors).
abstract final class BubblerTheme {
  static const Color blue = Color(0xFF1565C0);
  static const Color cyan = Color(0xFF00BCD4);
  static const Color deepBlue = Color(0xFF0D47A1);

  /// Feed / graph background (blue → cyan → indigo → black wash).
  static final LinearGradient feedGradient = LinearGradient(
    colors: [
      Colors.blue.withValues(alpha: 0.9),
      Colors.cyan.withValues(alpha: 0.55),
      Colors.indigo.withValues(alpha: 0.9),
      Colors.black.withValues(alpha: 0.3),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [
      Color(0xFF0D47A1),
      Color(0xFF00ACC1),
      Color(0xFF1565C0),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color glassFill([double alpha = 0.10]) =>
      Colors.white.withValues(alpha: alpha);

  static Color glassStroke([double alpha = 0.12]) =>
      Colors.white.withValues(alpha: alpha);

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
