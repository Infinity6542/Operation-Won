import 'package:flutter/material.dart';

/// App Color Palette - Centralized color management
class AppColors {
  AppColors._(); // Private constructor to prevent instantiation

  // Primary Colors
  static const Color primaryBlue = Color(0xFF2196F3);
  static const Color accentBlue = Color(0xff3b82f6);
  static const Color lightBlue = Color(0xff59dafb);
  static const Color secondaryGreen = Color(0xFF4CAF50);

  // Surface Colors
  static const Color surfaceBlack = Colors.black; // AMOLED black
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceDarker = Color(0xFF2A2A2A);
  static const Color surfaceCard = Color.fromARGB(255, 0, 3, 20);
  static const Color surfaceNavigation = Color(0xff0f172a);

  // Border & Divider Colors
  static const Color borderPrimary = Color(0xff334155);
  static const Color borderSecondary = Color(0xff64748b);

  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textMuted = Color(0xff94a3b8);
  static const Color textDisabled = Color(0xff64748b);
  static const Color textSemiTransparent = Color(0x80ffffff);

  // State Colors
  static const Color errorColor = Colors.redAccent;
  static const Color errorDark = Color(0xffef4444);

  // Alpha Colors (Pre-computed for performance)
  static final Color shadowColor = Colors.black.withValues(alpha: 0.3);
  static final Color borderAlpha = borderPrimary.withValues(alpha: 0.5);
  static final Color accentBlueAlpha30 = accentBlue.withValues(alpha: 0.3);
  static final Color borderSecondaryAlpha30 =
      borderSecondary.withValues(alpha: 0.3);
  static final Color accentBlueAlpha80 = accentBlue.withValues(alpha: 0.8);

  // Border Radius Values
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
}

// Pre-computed colors to improve performance (keeping for backward compatibility)
final _blackAlpha30 = AppColors.shadowColor;
final _borderAlpha50 = AppColors.borderAlpha;
final _blueAlpha30 = AppColors.accentBlueAlpha30;
final _grayAlpha30 = AppColors.borderSecondaryAlpha30;

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.lightBlue,
    brightness: Brightness.light,
    primary: AppColors.primaryBlue,
    secondary: AppColors.secondaryGreen,
    surface: Colors.white,
    onSurface: Colors.black87,
    surfaceContainer: const Color(0xFFF5F5F5),
    surfaceContainerHighest: const Color(0xFFE0E0E0),
    error: AppColors.errorColor,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.black87),
    bodyLarge: TextStyle(color: Colors.black87),
    bodySmall: TextStyle(color: Colors.black54),
    headlineLarge: TextStyle(color: Colors.black87),
    headlineMedium: TextStyle(color: Colors.black87),
    headlineSmall: TextStyle(color: Colors.black87),
    titleLarge: TextStyle(color: Colors.black87),
    titleMedium: TextStyle(color: Colors.black87),
    titleSmall: TextStyle(color: Colors.black87),
    labelLarge: TextStyle(color: Colors.black87),
    labelMedium: TextStyle(color: Colors.black45, fontSize: 10),
    labelSmall: TextStyle(color: Colors.black54),
  ),
  fontFamily: 'Inter',
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black87,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.1),
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      side: BorderSide(
        color: Colors.black.withValues(alpha: 0.1),
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.primaryBlue,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.primaryBlue,
      side: const BorderSide(color: Colors.black26),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.primaryBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSmall),
      ),
    ),
  ),
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(Colors.black87),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFFF5F5F5),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: Colors.black26),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: Colors.black26),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: BorderSide(color: AppColors.errorColor),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: BorderSide(color: AppColors.errorColor, width: 2),
    ),
    labelStyle: const TextStyle(color: Colors.black54),
    hintStyle: const TextStyle(color: Colors.black38),
    floatingLabelStyle: TextStyle(color: AppColors.primaryBlue),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primaryBlue;
      }
      return Colors.white;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.primaryBlue.withValues(alpha: 0.3);
      }
      return Colors.black26;
    }),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusSmall)),
      side: BorderSide(color: Colors.black12),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xFF323232),
    contentTextStyle: TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusSmall)),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 16,
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: AppColors.primaryBlue,
    unselectedItemColor: Colors.black54,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  tabBarTheme: TabBarThemeData(
    labelColor: Colors.black87,
    unselectedLabelColor: Colors.black54,
    indicatorColor: AppColors.primaryBlue,
    dividerColor: Colors.black12,
  ),
  dividerTheme: const DividerThemeData(
    color: Colors.black12,
    thickness: 1,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFF5F5F5),
    selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
    disabledColor: Colors.black12,
    labelStyle: const TextStyle(color: Colors.black87),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusSmall),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryBlue;
        }
        return Colors.white;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return Colors.black54;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        ),
      ),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: AppColors.primaryBlue,
    labelTextStyle: const WidgetStatePropertyAll(
      TextStyle(color: Colors.black54, fontSize: 12),
    ),
    iconTheme: const WidgetStatePropertyAll(
      IconThemeData(color: Colors.black54),
    ),
  ),
);

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primaryBlue,
    brightness: Brightness.dark,
    primary: AppColors.primaryBlue,
    secondary: AppColors.secondaryGreen,
    surface: AppColors.surfaceBlack,
    onSurface: AppColors.textPrimary,
    surfaceContainer: AppColors.surfaceDark,
    surfaceContainerHighest: AppColors.surfaceDarker,
    error: AppColors.errorColor,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: AppColors.textPrimary),
    bodyLarge: TextStyle(color: AppColors.textPrimary),
    bodySmall: TextStyle(color: AppColors.textSecondary),
    headlineLarge: TextStyle(color: AppColors.textPrimary),
    headlineMedium: TextStyle(color: AppColors.textPrimary),
    headlineSmall: TextStyle(color: AppColors.textPrimary),
    titleLarge: TextStyle(color: AppColors.textPrimary),
    titleMedium: TextStyle(color: AppColors.textPrimary),
    titleSmall: TextStyle(color: AppColors.textPrimary),
    labelLarge: TextStyle(color: AppColors.textPrimary),
    labelMedium: TextStyle(color: AppColors.textSemiTransparent, fontSize: 10),
    labelSmall: TextStyle(color: AppColors.textSecondary),
  ),
  fontFamily: 'Inter',
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.surfaceNavigation,
    foregroundColor: AppColors.textPrimary,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.surfaceCard,
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shadowColor: _blackAlpha30,
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      side: BorderSide(
        color: _borderAlpha50,
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accentBlue,
      foregroundColor: AppColors.textPrimary,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: AppColors.accentBlue,
      foregroundColor: AppColors.textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.textPrimary,
      side: const BorderSide(color: AppColors.borderSecondary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.lightBlue,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.radiusSmall),
      ),
    ),
  ),
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(AppColors.textPrimary),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surfaceCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: AppColors.borderSecondary),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: AppColors.borderSecondary),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: AppColors.accentBlue, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: AppColors.errorDark),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusMedium),
      borderSide: const BorderSide(color: AppColors.errorDark, width: 2),
    ),
    labelStyle: const TextStyle(color: AppColors.textMuted),
    hintStyle: const TextStyle(color: AppColors.borderSecondary),
    floatingLabelStyle: const TextStyle(color: AppColors.accentBlue),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return AppColors.accentBlue;
      }
      return AppColors.borderSecondary;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return _blueAlpha30;
      }
      return _grayAlpha30;
    }),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: AppColors.surfaceCard,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusSmall)),
      side: BorderSide(color: AppColors.borderPrimary),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: AppColors.surfaceCard,
    contentTextStyle: TextStyle(color: AppColors.textPrimary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusSmall)),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 16, // High elevation to appear above bottom sheets
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.surfaceCard,
    selectedItemColor: AppColors.accentBlue,
    unselectedItemColor: AppColors.textMuted,
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: AppColors.textPrimary,
    unselectedLabelColor: AppColors.textMuted,
    indicatorColor: AppColors.accentBlue,
    dividerColor: AppColors.borderSecondary,
  ),
  dividerTheme: const DividerThemeData(
    color: AppColors.borderSecondary,
    thickness: 1,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.surfaceCard,
    selectedColor: _blueAlpha30,
    disabledColor: AppColors.borderSecondary,
    labelStyle: const TextStyle(color: AppColors.textPrimary),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppColors.radiusSmall),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accentBlue;
        }
        return AppColors.surfaceCard;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.textPrimary;
        }
        return AppColors.textMuted;
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMedium),
        ),
      ),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: AppColors.surfaceNavigation,
    indicatorColor: AppColors.accentBlue,
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(color: AppColors.textMuted, fontSize: 12),
    ),
    iconTheme: WidgetStatePropertyAll(
      IconThemeData(color: AppColors.textMuted),
    ),
  ),
);
