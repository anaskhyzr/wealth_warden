import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const primaryGreen = Color(0xFF1ED760);
  static const accentGreen = Color(0xFF1DB954);
  static const defaultPrimaryColor = Color(0xFF1ED760);
  
  // This will be set once at app startup and not changed during build
  static Color primaryColor = defaultPrimaryColor;
  
  // Dark theme colors
  static const darkBackground = Color(0xFF121212);
  static const darkSurface = Color(0xFF1E1E1E);
  static const darkCard = Color(0xFF282828);
  static const darkError = Color(0xFFCF6679);
  
  // Text colors
  static const darkTextPrimary = Colors.white;
  static const darkTextSecondary = Color(0xFFB3B3B3);
  
  // Category colors
  static const categoryRed = Color(0xFFE74C3C);
  static const categoryBlue = Color(0xFF3498DB);
  static const categoryPurple = Color(0xFF9B59B6);
  static const categoryOrange = Color(0xFFE67E22);
  static const categoryTeal = Color(0xFF1ABC9C);
  
  // Transaction type colors
  static const expenseRed = Color(0xFFE74C3C);
  static const incomeGreen = Color(0xFF2ECC71);
  
  // Light theme colors
  static const lightBackground = Color(0xFFF0F0F0);
  static const lightSurface = Colors.white;
  static const lightError = Color(0xFFB00020);
  
  // Status colors
  static const successGreen = Color(0xFF1ED760);
  static const warningYellow = Color(0xFFFFD700);
  static const errorRed = Color(0xFFE74C3C);
}

class AppTheme {
  // Dark theme
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: AppColors.primaryGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.darkSurface,
      background: AppColors.darkBackground,
      error: AppColors.darkError,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
      onBackground: AppColors.darkTextPrimary,
      onError: Colors.black,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkBackground,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.darkTextPrimary,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkBackground,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: AppColors.darkTextSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primaryGreen,
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: AppColors.darkCard,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: AppColors.darkTextSecondary),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: AppColors.darkCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.darkTextPrimary,
      ),
      contentTextStyle: TextStyle(
        fontSize: 16,
        color: AppColors.darkTextSecondary,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkCard,
      contentTextStyle: TextStyle(color: AppColors.darkTextPrimary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade800,
      thickness: 0.5,
    ),
    iconTheme: IconThemeData(
      color: AppColors.darkTextPrimary,
      size: 24,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 24),
      headlineSmall: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.bold, fontSize: 20),
      titleLarge: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: AppColors.darkTextPrimary, fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 16),
      bodyMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
      bodySmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
    ),
  );

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: AppColors.primaryGreen,
      secondary: AppColors.accentGreen,
      surface: AppColors.lightSurface,
      background: AppColors.lightBackground,
      error: AppColors.lightError,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: Colors.black,
      onBackground: Colors.black,
      onError: Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      selectedItemColor: AppColors.primaryGreen,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 8),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppColors.primaryGreen,
          width: 1.5,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      hintStyle: TextStyle(color: Colors.grey),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        elevation: 0,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black,
      ),
      contentTextStyle: TextStyle(
        fontSize: 16,
        color: Colors.grey.shade700,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Colors.grey.shade900,
      contentTextStyle: TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    dividerTheme: DividerThemeData(
      color: Colors.grey.shade300,
      thickness: 0.5,
    ),
    iconTheme: IconThemeData(
      color: Colors.black,
      size: 24,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 28),
      headlineMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 24),
      headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
      titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 18),
      titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 16),
      titleSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w600, fontSize: 14),
      bodyLarge: TextStyle(color: Colors.black, fontSize: 16),
      bodyMedium: TextStyle(color: Colors.grey.shade700, fontSize: 14),
      bodySmall: TextStyle(color: Colors.grey.shade700, fontSize: 12),
    ),
  );
  
  // Helper methods for common UI components
  static BoxDecoration roundedBoxDecoration({
    Color? color,
    double radius = 16,
    Color? borderColor,
    double borderWidth = 0,
  }) {
    return BoxDecoration(
      color: color ?? AppColors.darkCard,
      borderRadius: BorderRadius.circular(radius),
      border: borderColor != null
          ? Border.all(color: borderColor, width: borderWidth)
          : null,
    );
  }
  
  static BoxDecoration greenGradientBox({
    double radius = 16,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [AppColors.primaryGreen, AppColors.accentGreen],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}
