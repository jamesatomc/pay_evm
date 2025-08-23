import 'package:flutter/material.dart';

class AppTheme {
  // Elegant, minimal palette: deep navy + soft gold accent
  static const Color primaryColor = Color(0xFF0B3D91); // deep navy
  static const Color primaryAccent = Color(0xFFC9A24A); // soft gold
  // kept for backwards compatibility with existing screens
  static const Color primaryVariant = Color(0xFF133C8F);
  static const Color secondaryColor = Color(0xFF00BFA6); // teal accent for success
  static const Color successColor = secondaryColor;
  static const Color errorColor = Color(0xFFEF4444);
  static const Color warningColor = Color(0xFFF59E0B);
  // Transparent alias to avoid direct Colors.transparent usage
  static const Color transparent = Color(0x00000000);
  // Common white alias to avoid direct Colors.white usage in widgets
  static const Color white = Color(0xFFFFFFFF);

  // Light Theme Colors
  static const Color lightSurfaceColor = Color(0xFFF6F7FB);
  static const Color lightBackgroundColor = Color(0xFFFFFFFF);
  static const Color lightCardColor = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF0F1724);
  static const Color lightTextSecondary = Color(0xFF51607A);
  static const Color lightTextMuted = Color(0xFF94A3B8);

  // Dark Theme Colors
  static const Color darkSurfaceColor = Color(0xFF0B1220);
  static const Color darkBackgroundColor = Color(0xFF071026);
  static const Color darkCardColor = Color(0xFF0F1724);
  static const Color darkTextPrimary = Color(0xFFF7FAFC);
  static const Color darkTextSecondary = Color(0xFFCBD5E1);
  static const Color darkTextMuted = Color(0xFF94A3B8);

  // Dynamic colors based on theme mode (updated at runtime)
  static Color surfaceColor = lightSurfaceColor;
  static Color backgroundColor = lightBackgroundColor;
  static Color cardColor = lightCardColor;
  static Color textPrimary = lightTextPrimary;
  static Color textSecondary = lightTextSecondary;
  static Color textMuted = lightTextMuted;

  static void updateThemeColors(bool isDark) {
    if (isDark) {
      surfaceColor = darkSurfaceColor;
      backgroundColor = darkBackgroundColor;
      cardColor = darkCardColor;
      textPrimary = darkTextPrimary;
      textSecondary = darkTextSecondary;
      textMuted = darkTextMuted;
    } else {
      surfaceColor = lightSurfaceColor;
      backgroundColor = lightBackgroundColor;
      cardColor = lightCardColor;
      textPrimary = lightTextPrimary;
      textSecondary = lightTextSecondary;
      textMuted = lightTextMuted;
    }
  }

  // Subtle gradients for cards
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0F3A8C), Color(0xFF133C8F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [darkSurfaceColor, darkBackgroundColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Radii & spacing tuned for a refined look
  static const double borderRadiusSmall = 10.0;
  static const double borderRadiusMedium = 14.0;
  static const double borderRadiusLarge = 18.0;
  static const double borderRadiusXLarge = 26.0;

  static const double spacingXS = 6.0;
  static const double spacingS = 10.0;
  static const double spacingM = 16.0;
  static const double spacingL = 22.0;
  static const double spacingXL = 32.0;

  // Softer shadows for depth
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ];

  // Light theme
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.light,
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: lightSurfaceColor,
      background: lightBackgroundColor,
      onPrimary: Colors.white,
      onSurface: lightTextPrimary,
    ),
    scaffoldBackgroundColor: lightSurfaceColor,
    cardTheme: CardThemeData(
      color: lightCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
      ),
      shadowColor: Colors.black.withOpacity(0.06),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: lightTextPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: lightTextPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor.withOpacity(0.14)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadiusMedium),
        ),
        padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: lightBackgroundColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide(color: primaryColor.withOpacity(0.9), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
        borderSide: BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingM),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: lightTextPrimary, fontSize: 30, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: lightTextPrimary, fontSize: 26, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: lightTextPrimary, fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: lightTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: lightTextPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: lightTextSecondary, fontSize: 14),
      bodySmall: TextStyle(color: lightTextMuted, fontSize: 12),
      labelLarge: TextStyle(color: lightTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: Brightness.dark,
      primary: primaryColor,
      secondary: secondaryColor,
      error: errorColor,
      surface: darkSurfaceColor,
      background: darkBackgroundColor,
      onPrimary: Colors.white,
      onSurface: darkTextPrimary,
    ),
    scaffoldBackgroundColor: darkSurfaceColor,
    cardTheme: CardThemeData(
      color: darkCardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadiusMedium),
      ),
      shadowColor: Colors.black.withOpacity(0.18),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: darkTextPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadiusMedium)),
        padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: Colors.white.withOpacity(0.08)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadiusMedium)),
        padding: const EdgeInsets.symmetric(horizontal: spacingL, vertical: spacingS),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkCardColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadiusMedium), borderSide: BorderSide(color: Colors.grey.shade800)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadiusMedium), borderSide: BorderSide(color: Colors.grey.shade800)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadiusMedium), borderSide: BorderSide(color: primaryColor.withOpacity(0.9), width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadiusMedium), borderSide: BorderSide(color: errorColor)),
      contentPadding: const EdgeInsets.symmetric(horizontal: spacingM, vertical: spacingM),
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(color: darkTextPrimary, fontSize: 30, fontWeight: FontWeight.w700),
      headlineMedium: TextStyle(color: darkTextPrimary, fontSize: 26, fontWeight: FontWeight.w700),
      headlineSmall: TextStyle(color: darkTextPrimary, fontSize: 22, fontWeight: FontWeight.w600),
      titleLarge: TextStyle(color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      titleMedium: TextStyle(color: darkTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: darkTextPrimary, fontSize: 15),
      bodyMedium: TextStyle(color: darkTextSecondary, fontSize: 14),
      bodySmall: TextStyle(color: darkTextMuted, fontSize: 12),
      labelLarge: TextStyle(color: darkTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );
}

// Custom widget extensions
extension AppWidgets on Widget {
  Widget withPadding([EdgeInsets? padding]) {
    return Padding(padding: padding ?? const EdgeInsets.all(AppTheme.spacingM), child: this);
  }

  Widget withCard([EdgeInsets? margin]) {
    return Card(margin: margin ?? const EdgeInsets.all(AppTheme.spacingS), child: this);
  }
}
