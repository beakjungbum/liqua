import 'package:flutter/material.dart';

/// 발표 시안의 올리브 팔레트. 흰 글씨 대비를 4.5:1 이상으로 맞추려고 카드 바탕만 조금 어둡게 했다.
class AppColors {
  static const background = Color(0xFFFFFFFF);
  static const card = Color(0xFFF8F8F4);
  static const line = Color(0xFFE4E6DA);
  static const olive = Color(0xFF69704F);
  static const oliveSoft = Color(0xFF8F9576);
  static const sage = Color(0xFFBBBFA2);
  static const mist = Color(0xFFDFE2D2);
  static const deep = Color(0xFF3F452E);
  static const text = Color(0xFF2C3022);
  static const sub = Color(0xFF666B58);
  static const accent = Color(0xFFC4581F);
  static const accentSoft = Color(0xFFFCE9DC);

  static const chart = [deep, oliveSoft, sage, Color(0xFFE5A272), mist, Color(0xFFA7B8A8), Color(0xFFCDB98A), Color(0xFF7D8F83), line];
}

class AppTheme {
  static final ThemeData light = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.olive).copyWith(
        primary: AppColors.olive, onPrimary: Colors.white, surface: AppColors.background, onSurface: AppColors.text, error: AppColors.accent),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.olive, selectionColor: AppColors.mist, selectionHandleColor: AppColors.olive),
    appBarTheme: const AppBarTheme(backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent, foregroundColor: AppColors.text, centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      labelStyle: TextStyle(color: AppColors.sub),
      hintStyle: TextStyle(color: AppColors.sub),
      helperStyle: TextStyle(color: AppColors.sub),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.olive, width: 1.6)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.accent)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14)), borderSide: BorderSide(color: AppColors.accent, width: 1.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            backgroundColor: AppColors.olive, foregroundColor: Colors.white, minimumSize: const Size(64, 50), shape: const StadiumBorder(),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.olive, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    chipTheme: const ChipThemeData(
        backgroundColor: AppColors.card, selectedColor: AppColors.mist, side: BorderSide(color: AppColors.line), showCheckmark: false,
        labelStyle: TextStyle(color: AppColors.text, fontSize: 13)),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.deep),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.olive),
    dividerTheme: const DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
    switchTheme: SwitchThemeData(trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.olive : AppColors.mist)),
  );
}
