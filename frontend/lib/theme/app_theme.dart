// lib/theme/app_theme.dart
//
// Builds the MaterialApp ThemeData that applies the design system
// globally — so widgets like ElevatedButton, TextField, AppBar
// automatically pick up the right colors without extra code.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.backgroundDeep,

      // ── Color scheme ──────────────────────────────────────────
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.peach,
        secondary: AppColors.teal,
        surface:   AppColors.backgroundCard,
        error:     Color(0xFFCF6679),
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),

      // ── AppBar ─────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor:  AppColors.backgroundDeep,
        elevation:        0,
        centerTitle:      true,
        titleTextStyle:   AppTextStyles.logo,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor:           Colors.transparent,
          statusBarIconBrightness:  Brightness.light,
        ),
        iconTheme: IconThemeData(color: AppColors.textSecondary),
      ),

      // ── ElevatedButton ─────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppColors.peach,
          foregroundColor:  Colors.white,
          disabledBackgroundColor: AppColors.backgroundElevated,
          disabledForegroundColor: AppColors.textHint,
          textStyle:        AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize:      const Size(double.infinity, 56),
          elevation:        0,
        ),
      ),

      // ── OutlinedButton ─────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor:  AppColors.textPrimary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          textStyle:        AppTextStyles.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          minimumSize:      const Size(double.infinity, 56),
        ),
      ),

      // ── TextButton ─────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          textStyle: AppTextStyles.sectionLabel,
        ),
      ),

      // ── TextField / Input ──────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled:          true,
        fillColor:       AppColors.backgroundElevated,
        hintStyle:       AppTextStyles.sectionLabel.copyWith(
          color: AppColors.textHint,
          letterSpacing: 0.5,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.peach, width: 2),
        ),
      ),

      // ── Divider ────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color:     AppColors.border,
        thickness: 1,
        space:     24,
      ),

      // ── SnackBar ───────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor:  AppColors.backgroundElevated,
        contentTextStyle: AppTextStyles.button.copyWith(fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Bottom Navigation Bar ──────────────────────────────────
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor:      AppColors.navBackground,
        selectedItemColor:    AppColors.peach,
        unselectedItemColor:  AppColors.textSecondary,
        type:                 BottomNavigationBarType.fixed,
        elevation:            0,
        selectedLabelStyle:   TextStyle(
          fontFamily:   'Poppins',
          fontSize:     11,
          fontWeight:   FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontFamily:   'Poppins',
          fontSize:     11,
          fontWeight:   FontWeight.w500,
        ),
      ),
    );
  }
}
