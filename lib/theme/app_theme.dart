import 'package:flutter/material.dart';

class AppColors {
  static const background = Color.fromRGBO(245, 243, 238, 1);
  static const text = Color.fromRGBO(34, 40, 37, 1);
  static const primary = Color.fromRGBO(204, 213, 174, 1);
  static const surface = Color.fromRGBO(252,175,88,1);
  static const bar = Color.fromRGBO(96, 108, 56,1);
  static const bar2 = Color.fromRGBO(254, 234, 199,1);
  static const navy = Color(0xFF003876);
  static const expense = Color(0xFFF04452);
  static const sub = Color(0xFF8B95A1);
}

class AppTheme {
  static ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.bar,
      hintStyle: TextStyle(color: AppColors.sub, fontSize: 15),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide.none,
        ),
        ),
        chipTheme: const ChipThemeData(
          backgroundColor: AppColors.bar,
          selectedColor: AppColors.primary,
          side: BorderSide.none,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.bar,
              minimumSize: const Size.fromHeight(52),
            ),
          ),
    );
  }