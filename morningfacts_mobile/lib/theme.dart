import 'package:material_ui/material_ui.dart';

/// The "Paper" style: white ground, serif headings, one orange accent.
class AppColors {
  static const orange = Color(0xFFD9531E);
  static const ink = Color(0xFF141414);
  static const muted = Color(0xFF555555);
  static const paper = Color(0xFFF5F1EA);
  static const line = Color(0xFFE4E0D8);
  static const white = Color(0xFFFFFFFF);
  static const correct = Color(0xFF1E7A46);
  static const correctBg = Color(0xFFEAF6EF);
  static const wrong = Color(0xFFB3261E);
  static const wrongBg = Color(0xFFFBEAE9);
}

class AppText {
  static const serif = 'Lora';
  static const sans = 'Inter';

  static const display = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w700,
    fontSize: 32,
    height: 1.15,
    color: AppColors.ink,
  );
  static const title = TextStyle(
    fontFamily: serif,
    fontWeight: FontWeight.w700,
    fontSize: 26,
    height: 1.2,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 17,
    height: 1.5,
    color: AppColors.ink,
  );
  static const small = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w400,
    fontSize: 13,
    height: 1.4,
    color: AppColors.muted,
  );
  static const label = TextStyle(
    fontFamily: sans,
    fontWeight: FontWeight.w700,
    fontSize: 12,
    letterSpacing: 1.0,
    color: AppColors.muted,
  );
}

ThemeData buildTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: AppText.sans,
    scaffoldBackgroundColor: AppColors.white,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange, primary: AppColors.orange, surface: AppColors.white),
    splashFactory: InkRipple.splashFactory,
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.ink,
      checkmarkColor: AppColors.white,
      side: const BorderSide(color: AppColors.line, width: 1.5),
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.ink : AppColors.white,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? AppColors.white : AppColors.ink,
        ),
        side: const WidgetStatePropertyAll(BorderSide(color: AppColors.line, width: 1.5)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontFamily: AppText.sans, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
      ),
    ),
  );
}
