// lib/theme/app_theme.dart
/// AppTheme - The central design system for iPark.
/// 
/// Defines the color palette, typography, component styles, and responsive 
/// scaling utilities for both Light and Dark modes.

import 'package:flutter/material.dart';

class AppTheme {
  // --- Brand Colors ---
  // The primary blue used throughout the app for buttons, icons, and highlights.
  static const Color primaryLight = Color(0xFF00B4D8); 
  static const Color primaryDark = Color(0xFF00B4D8);
  
  // --- Background Colors ---
  static const Color bgLight = Colors.white; 
  static const Color cardLight = Color(0xFFF5F7FA); // Soft off-white for cards/containers
  static const Color bgDark = Color(0xFF121212);    // Standard material dark background
  
  // --- Text Colors ---
  static const Color textLight = Color.fromARGB(255, 0, 0, 0);
  static const Color textDark = Color(0xFFE0E0E0);

  /// Defines the Light Theme configuration.
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: primaryLight,
    scaffoldBackgroundColor: bgLight,
    cardColor: cardLight,
    canvasColor: cardLight,
    
    // Transparent app bar for a modern, flat look
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: primaryLight),
      titleTextStyle: TextStyle(color: primaryLight, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    
    // Typography using the 'Poppins' font family
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textLight, fontFamily: 'Poppins'),
      bodyMedium: TextStyle(color: textLight, fontFamily: 'Poppins'),
    ),
    
    // Global button styling
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
    ),
  );

  /// Defines the Dark Theme configuration.
  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryLight,
    scaffoldBackgroundColor: bgDark,
    
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: primaryLight),
      titleTextStyle: TextStyle(color: primaryLight, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: textDark, fontFamily: 'Poppins'),
      bodyMedium: TextStyle(color: textDark, fontFamily: 'Poppins'),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryLight,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
    ),
  );

  // --- Responsive Utilities ---

  /// Returns a scaling factor based on the device width.
  /// Useful for maintaining proportions on tablets vs small phones.
  static double getScale(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    if (width > 600) return 1.15; // Upscale for Tablets
    if (width < 360) return 0.9;  // Downscale for Small Phones
    return 1.0;                   // Standard scale for average phones
  }

  /// Calculates a responsive size for fonts, padding, or icons.
  static double respSize(BuildContext context, double size) {
    return size * getScale(context);
  }
}