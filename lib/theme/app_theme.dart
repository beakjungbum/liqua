import 'package:flutter/material.dart';

/// 팀 팔레트. 밝은 화면과 어두운 화면이 같은 이름을 쓴다.
abstract final class AppColors {
  static var dark = false;
  static Color _p(int light, int night) => Color(dark ? night : light);

  // 팀이 정한 색
  static const main = Color(0xFFAEB68A); // 파스텔 올리브
  static const sage = Color(0xFFC9CEAC); // 소프트 세이지
  static const peach = Color(0xFFEFB18D); // 피치 오렌지
  static const orange = Color(0xFFFF7133); // 주요 버튼
  static const ink = Color(0xFF11180F); // 다크 그린

  static Color get background => _p(0xFFF5F8ED, 0xFF11180F);
  static Color get deep => _p(0xFF777D58, 0xFFC9CEAC); // 큰 글자 강조
  static Color get text => _p(0xFF11180F, 0xFFF5F8ED);

  // 작은 글씨 대비 4.5:1 을 지키려고 팔레트에서 파생한 색
  static Color get card => _p(0xFFFFFFFF, 0xFF1B2418);
  static Color get line => _p(0xFFDFE4CC, 0xFF2E3A29);
  static Color get mist => _p(0xFFE4E8D2, 0xFF2A3522);
  static Color get olive => _p(0xFF777D58, 0xFFAEB68A);
  static Color get sub => _p(0xFF565C3E, 0xFFAEB68A);
  static Color get accent => _p(0xFFA63C0B, 0xFFEFB18D);
  static Color get accentSoft => _p(0xFFFCEBDF, 0xFF3A2417);

  static const chart = [Color(0xFF777D58), main, peach, sage, orange, Color(0xFF5A6B4F), Color(0xFFD9C9A3), Color(0xFF94A08A), Color(0xFFBFC7B5)];
}

class AppTheme {
  static ThemeData get current {
    OutlineInputBorder b(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: c, width: w));
    final base = AppColors.dark ? Brightness.dark : Brightness.light;
    return ThemeData(
      useMaterial3: true,
      brightness: base,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.main, brightness: base).copyWith(
          primary: AppColors.orange, onPrimary: AppColors.ink, surface: AppColors.background, onSurface: AppColors.text, onSurfaceVariant: AppColors.sub, error: AppColors.accent),
      textSelectionTheme: TextSelectionThemeData(cursorColor: AppColors.orange, selectionColor: AppColors.mist, selectionHandleColor: AppColors.orange),
      appBarTheme: AppBarTheme(
          backgroundColor: AppColors.background, surfaceTintColor: Colors.transparent, foregroundColor: AppColors.text, centerTitle: false,
          titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.text)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true, fillColor: AppColors.card,
          labelStyle: TextStyle(color: AppColors.sub), floatingLabelStyle: TextStyle(color: AppColors.sub), hintStyle: TextStyle(color: AppColors.sub), helperStyle: TextStyle(color: AppColors.sub),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: b(AppColors.line), focusedBorder: b(AppColors.olive, 1.6), errorBorder: b(AppColors.accent), focusedErrorBorder: b(AppColors.accent, 1.6)),
      // 주황 위 흰 글씨는 대비가 모자라 다크 그린 글씨를 쓴다.
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.orange, foregroundColor: AppColors.ink, disabledBackgroundColor: AppColors.mist, disabledForegroundColor: AppColors.sub,
              minimumSize: const Size(64, 50), shape: const StadiumBorder(), textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: AppColors.sub, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
      chipTheme: ChipThemeData(
          backgroundColor: AppColors.card, selectedColor: AppColors.mist, side: BorderSide(color: AppColors.line), showCheckmark: false,
          labelStyle: TextStyle(color: AppColors.text, fontSize: 13)),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AppColors.main, contentTextStyle: TextStyle(color: AppColors.ink)),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.olive),
      dividerTheme: DividerThemeData(color: AppColors.line, space: 1, thickness: 1),
      switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : AppColors.sub),
          trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.orange : AppColors.mist)),
    );
  }
}
