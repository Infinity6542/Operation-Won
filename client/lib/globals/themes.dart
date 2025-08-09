import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff59dafb),
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(),
  fontFamily: 'Inter',
);

@NowaGenerated()
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xff59dafb),
    brightness: Brightness.dark,
    surface: const Color(0xff0f172a),
    onSurface: const Color(0xffffffff),
    surfaceContainerHighest: const Color(0xff1e293b),
    surfaceContainer: const Color(0xff334155),
    outline: const Color(0xff64748b),
    secondary: const Color(0xffb0fa6f),
    primary: const Color(0xff59dafb),
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: Colors.white),
    bodyLarge: TextStyle(color: Colors.white),
    bodySmall: TextStyle(color: Colors.white70),
    headlineLarge: TextStyle(color: Colors.white),
    headlineMedium: TextStyle(color: Colors.white),
    headlineSmall: TextStyle(color: Colors.white),
    titleLarge: TextStyle(color: Colors.white),
    titleMedium: TextStyle(color: Colors.white),
    titleSmall: TextStyle(color: Colors.white),
    labelLarge: TextStyle(color: Colors.white),
    labelMedium: TextStyle(color: Color(0x80ffffff), fontSize: 10),
    labelSmall: TextStyle(color: Colors.white70),
  ),
  fontFamily: 'Inter',
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xff0f172a),
    foregroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xff1e293b),
    surfaceTintColor: Colors.transparent,
    elevation: 1,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    margin: const EdgeInsets.all(8),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: const Color(0xff334155).withValues(alpha: 0.5),
        width: 1,
      ),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xff3b82f6),
      foregroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: const Color(0xff3b82f6),
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: Colors.white,
      side: const BorderSide(color: Color(0xff64748b)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xff59dafb),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  ),
  iconButtonTheme: const IconButtonThemeData(
    style: ButtonStyle(
      foregroundColor: WidgetStatePropertyAll<Color>(Colors.white),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xff1e293b),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff64748b)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff64748b)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xff3b82f6), width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffef4444)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xffef4444), width: 2),
    ),
    labelStyle: const TextStyle(color: Color(0xff94a3b8)),
    hintStyle: const TextStyle(color: Color(0xff64748b)),
    floatingLabelStyle: const TextStyle(color: Color(0xff3b82f6)),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xff3b82f6);
      }
      return const Color(0xff64748b);
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const Color(0xff3b82f6).withValues(alpha: 0.3);
      }
      return const Color(0xff64748b).withValues(alpha: 0.3);
    }),
  ),
  dialogTheme: const DialogThemeData(
    backgroundColor: Color(0xff1e293b),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      side: BorderSide(color: Color(0xff334155)),
    ),
  ),
  snackBarTheme: const SnackBarThemeData(
    backgroundColor: Color(0xff1e293b),
    contentTextStyle: TextStyle(color: Colors.white),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(8)),
    ),
    behavior: SnackBarBehavior.floating,
    elevation: 16, // High elevation to appear above bottom sheets
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xff0f172a),
    selectedItemColor: Color(0xff3b82f6),
    unselectedItemColor: Color(0xff64748b),
    type: BottomNavigationBarType.fixed,
    elevation: 8,
  ),
  tabBarTheme: const TabBarThemeData(
    labelColor: Color(0xff3b82f6),
    unselectedLabelColor: Color(0xff64748b),
    indicatorColor: Color(0xff3b82f6),
    dividerColor: Color(0xff334155),
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xff334155),
    thickness: 1,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xff1e293b),
    labelStyle: const TextStyle(color: Colors.white),
    selectedColor: const Color(0xff3b82f6),
    secondarySelectedColor: const Color(0xff3b82f6).withValues(alpha: 0.8),
    brightness: Brightness.dark,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const Color(0xff3b82f6);
        }
        return const Color(0xff1e293b);
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return const Color(0xff94a3b8);
      }),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
  ),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xff0f172a),
    indicatorColor: Color(0xff3b82f6),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(color: Color(0xff94a3b8), fontSize: 12),
    ),
    iconTheme: WidgetStatePropertyAll(
      IconThemeData(color: Color(0xff94a3b8)),
    ),
  ),
);
