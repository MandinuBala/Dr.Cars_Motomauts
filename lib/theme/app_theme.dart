import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Vibrant Color Palette (aligned with Motornauts THEME-V3) ─────
class AppColors {
  // Base — pure/cool black hierarchy
  static const Color obsidian = Color(0xFF000000); // deepest black
  static const Color richBlack = Color(0xFF000000); // app background
  static const Color surfaceDark = Color(0xFF101014); // card surface
  static const Color surfaceElevated = Color(0xFF18181D); // elevated cards
  static const Color surfaceGlass = Color(0xFF0A0A0C); // glass / sunken

  // Cyan accent system (replaces gold)
  static const Color gold = Color(0xFF00E5FF); // primary cyan (electric)
  static const Color goldLight = Color(0xFF33ECFF); // hover / highlight
  static const Color goldDark = Color(0xFF00B8CC); // pressed / shadow
  static const Color goldMuted = Color(
    0x1F00E5FF,
  ); // rgba(0,229,255,0.12) — muted fill

  // Magenta secondary
  static const Color magenta = Color(0xFFFF2D95); // secondary emphasis
  static const Color magentaMuted = Color(0x1FFF2D95); // rgba(255,45,149,0.12)

  // Text — cool whites
  static const Color textPrimary = Color(
    0xFFF5F7FA,
  ); // cool white  (AAA on #000)
  static const Color textSecondary = Color(0xFFA8B0BC); // cool grey   (AA)
  static const Color textMuted = Color(0xFF6C7480); // tertiary

  // Functional / status
  static const Color success = Color(0xFF21E07A); // vibrant emerald
  static const Color error = Color(0xFFFF3D55); // vivid coral
  static const Color warning = Color(0xFFFFB400); // vibrant amber

  // Borders — low-alpha whites (never compete with neon)
  static const Color borderSubtle = Color(0x0FFFFFFF); // rgba(255,255,255,0.06)
  static const Color borderGold = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)

  // Light mode (unchanged — light mode out of scope per Motornauts V3)
  static const Color lightBackground = Color(0xFFFAF8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF5F0E8);
  static const Color lightBorder = Color(0xFFE8DFD0);
  static const Color lightTextPrimary = Color(0xFF1A1209);
  static const Color lightTextSecondary = Color(0xFF6B5B45);

  // Focus glow
  static const Color glowAccent = Color(0x4D00E5FF); // rgba(0,229,255,0.30)
  static const Color glowDanger = Color(0x4DFF3D55); // rgba(255,61,85,0.30)
}

// ── App-wide color constants (kept for backward compat) ───────────
const Color kAppBarColor = AppColors.obsidian;
const Color kAccentOrange = AppColors.gold; // now cyan
const Color kBlueTint = AppColors.gold; // now cyan
const Color kVehicleCardBg = AppColors.surfaceDark;
const Color kErrorRed = AppColors.error;
const Color kIconBgOpacityBlue = Color(0x1F00E5FF); // cyan at 12% opacity

// ── Typography ────────────────────────────────────────────────────
TextTheme _buildTextTheme(bool isDark) {
  final primary = isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  final secondary =
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  return TextTheme(
    // Display — Cormorant Garamond for luxury headings
    displayLarge: GoogleFonts.cormorantGaramond(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: primary,
      letterSpacing: 0.5,
    ),
    displayMedium: GoogleFonts.cormorantGaramond(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: primary,
      letterSpacing: 0.3,
    ),
    displaySmall: GoogleFonts.cormorantGaramond(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: primary,
    ),

    // Headlines
    headlineLarge: GoogleFonts.cormorantGaramond(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      color: primary,
      letterSpacing: 0.2,
    ),
    headlineMedium: GoogleFonts.cormorantGaramond(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    headlineSmall: GoogleFonts.cormorantGaramond(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: primary,
    ),

    // Titles — Jost for clean UI text
    titleLarge: GoogleFonts.jost(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: primary,
      letterSpacing: 0.3,
    ),
    titleMedium: GoogleFonts.jost(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: primary,
      letterSpacing: 0.5,
    ),
    titleSmall: GoogleFonts.jost(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: secondary,
      letterSpacing: 0.3,
    ),

    // Body
    bodyLarge: GoogleFonts.jost(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: GoogleFonts.jost(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    bodySmall: GoogleFonts.jost(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),

    // Labels — cyan replaces gold
    labelLarge: GoogleFonts.jost(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.gold,
      letterSpacing: 1.5,
    ),
    labelMedium: GoogleFonts.jost(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: AppColors.gold,
      letterSpacing: 1.2,
    ),
    labelSmall: GoogleFonts.jost(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.goldDark,
      letterSpacing: 1.0,
    ),
  );
}

// ── ThemeData Builder ─────────────────────────────────────────────
ThemeData buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final background = isDark ? AppColors.richBlack : AppColors.lightBackground;
  final surface = isDark ? AppColors.surfaceDark : AppColors.lightSurface;
  final surfaceAlt =
      isDark ? AppColors.surfaceElevated : AppColors.lightSurfaceAlt;
  final borderColor = isDark ? AppColors.borderSubtle : AppColors.lightBorder;
  final textPrimary =
      isDark ? AppColors.textPrimary : AppColors.lightTextPrimary;
  final textSecondary =
      isDark ? AppColors.textSecondary : AppColors.lightTextSecondary;

  return ThemeData(
    brightness: brightness,
    useMaterial3: false,
    primaryColor: AppColors.obsidian,
    scaffoldBackgroundColor: background,

    // ── Color Scheme ──────────────────────────────────────────────
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: AppColors.gold, // electric cyan
      onPrimary: Color(0xFF001318), // dark ink on cyan (AAA)
      secondary: AppColors.magenta, // hot magenta
      onSecondary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: surface,
      onSurface: textPrimary,
    ),

    // ── Typography ────────────────────────────────────────────────
    textTheme: _buildTextTheme(isDark),

    // ── AppBar ────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.obsidian,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.cormorantGaramond(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: 1.0,
      ),
      iconTheme: const IconThemeData(color: AppColors.gold),
      actionsIconTheme: const IconThemeData(color: AppColors.gold),
    ),

    // ── Cards ─────────────────────────────────────────────────────
    cardTheme: CardTheme(
      color: surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1),
      ),
    ),

    // ── Input Fields ──────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceAlt,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      hintStyle: GoogleFonts.jost(color: textSecondary, fontSize: 14),
      labelStyle: GoogleFonts.jost(color: textSecondary, fontSize: 14),
      floatingLabelStyle: GoogleFonts.jost(
        color: AppColors.gold,
        fontSize: 12,
        letterSpacing: 0.5,
      ),
    ),

    // ── Elevated Buttons ──────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(
          0xFF001318,
        ), // dark ink on cyan — AAA contrast
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.jost(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      ),
    ),

    // ── Outlined Buttons ──────────────────────────────────────────
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.gold,
        side: const BorderSide(color: AppColors.gold, width: 1),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: GoogleFonts.jost(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
        ),
      ),
    ),

    // ── Text Buttons ──────────────────────────────────────────────
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.gold,
        textStyle: GoogleFonts.jost(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),

    // ── Switch ────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith<Color>(
        (states) =>
            states.contains(WidgetState.selected)
                ? AppColors.gold
                : (isDark ? Colors.grey.shade600 : Colors.grey.shade400),
      ),
      trackColor: WidgetStateProperty.resolveWith<Color>(
        (states) =>
            states.contains(WidgetState.selected)
                ? AppColors.goldMuted
                : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
      ),
    ),

    // ── Bottom Navigation ─────────────────────────────────────────
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: isDark ? AppColors.obsidian : AppColors.lightSurface,
      selectedItemColor: AppColors.gold,
      unselectedItemColor:
          isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
      elevation: 0,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: false,
      showUnselectedLabels: false,
    ),

    // ── Divider ───────────────────────────────────────────────────
    dividerTheme: DividerThemeData(color: borderColor, thickness: 1, space: 1),

    // ── Icon ──────────────────────────────────────────────────────
    iconTheme: IconThemeData(
      color: isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
    ),

    // ── ListTile ──────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      textColor: textPrimary,
      iconColor: AppColors.gold,
      tileColor: Colors.transparent,
    ),

    // ── Dropdown ──────────────────────────────────────────────────
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      textStyle: GoogleFonts.jost(color: textPrimary, fontSize: 14),
      menuStyle: MenuStyle(backgroundColor: WidgetStatePropertyAll(surfaceAlt)),
    ),

    // ── Tab Bar ───────────────────────────────────────────────────
    tabBarTheme: TabBarTheme(
      labelColor: AppColors.gold,
      unselectedLabelColor:
          isDark ? AppColors.textMuted : AppColors.lightTextSecondary,
      indicatorColor: AppColors.gold,
      labelStyle: GoogleFonts.jost(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      unselectedLabelStyle: GoogleFonts.jost(
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
    ),

    // ── Chip ──────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: surfaceAlt,
      selectedColor: AppColors.goldMuted,
      labelStyle: GoogleFonts.jost(fontSize: 13, color: textPrimary),
      side: BorderSide(color: borderColor),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    ),

    // ── Expansion Tile ────────────────────────────────────────────
    expansionTileTheme: ExpansionTileThemeData(
      backgroundColor: surface,
      collapsedBackgroundColor: surface,
      iconColor: AppColors.gold,
      collapsedIconColor:
          isDark ? AppColors.textSecondary : AppColors.lightTextSecondary,
      textColor: textPrimary,
      collapsedTextColor: textPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      collapsedShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
    ),
  );
}

// ── Reusable Widgets ──────────────────────────────────────────────

/// Cyan gradient divider (replaces gold divider)
Widget goldDivider() => Container(
  height: 1,
  margin: const EdgeInsets.symmetric(vertical: 16),
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      colors: [Colors.transparent, AppColors.gold, Colors.transparent],
    ),
  ),
);

/// Section label in cyan uppercase
Widget luxuryLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Text(
    text.toUpperCase(),
    style: GoogleFonts.jost(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 2.5,
      color: AppColors.gold,
    ),
  ),
);

/// Cyan left-border card
BoxDecoration goldBorderCard({bool isDark = true}) => BoxDecoration(
  color: isDark ? AppColors.surfaceDark : AppColors.lightSurface,
  borderRadius: BorderRadius.circular(16),
  border: Border(
    left: const BorderSide(color: AppColors.gold, width: 3),
    top: BorderSide(
      color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
    ),
    right: BorderSide(
      color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
    ),
    bottom: BorderSide(
      color: isDark ? AppColors.borderSubtle : AppColors.lightBorder,
    ),
  ),
  boxShadow: [
    BoxShadow(
      color: AppColors.gold.withOpacity(0.08),
      blurRadius: 20,
      spreadRadius: 0,
      offset: const Offset(0, 4),
    ),
  ],
);
