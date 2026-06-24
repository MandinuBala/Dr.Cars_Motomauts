import 'package:flutter/material.dart';

@immutable
class MotornautsThemeColors extends ThemeExtension<MotornautsThemeColors> {
  const MotornautsThemeColors({
    required this.page,
    required this.subtle,
    required this.surface,
    required this.elevated,
    required this.overlay,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textOnAccent,
    required this.borderSubtle,
    required this.borderDefault,
    required this.borderStrong,
    required this.accent,
    required this.accentHover,
    required this.accentMuted,
    required this.accentSubtle,
    required this.secondaryAccent,
    required this.secondaryAccentMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
  });

  final Color page;
  final Color subtle;
  final Color surface;
  final Color elevated;
  final Color overlay;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textOnAccent;
  final Color borderSubtle;
  final Color borderDefault;
  final Color borderStrong;
  final Color accent;
  final Color accentHover;
  final Color accentMuted;
  final Color accentSubtle;
  final Color secondaryAccent;
  final Color secondaryAccentMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  static MotornautsThemeColors of(BuildContext context) {
    return Theme.of(context).extension<MotornautsThemeColors>()!;
  }

  Color statusBackground(Color color) => color.withValues(alpha: 0.12);

  Color statusBorder(Color color) => color.withValues(alpha: 0.40);

  @override
  MotornautsThemeColors copyWith({
    Color? page,
    Color? subtle,
    Color? surface,
    Color? elevated,
    Color? overlay,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textOnAccent,
    Color? borderSubtle,
    Color? borderDefault,
    Color? borderStrong,
    Color? accent,
    Color? accentHover,
    Color? accentMuted,
    Color? accentSubtle,
    Color? secondaryAccent,
    Color? secondaryAccentMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
  }) {
    return MotornautsThemeColors(
      page: page ?? this.page,
      subtle: subtle ?? this.subtle,
      surface: surface ?? this.surface,
      elevated: elevated ?? this.elevated,
      overlay: overlay ?? this.overlay,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textOnAccent: textOnAccent ?? this.textOnAccent,
      borderSubtle: borderSubtle ?? this.borderSubtle,
      borderDefault: borderDefault ?? this.borderDefault,
      borderStrong: borderStrong ?? this.borderStrong,
      accent: accent ?? this.accent,
      accentHover: accentHover ?? this.accentHover,
      accentMuted: accentMuted ?? this.accentMuted,
      accentSubtle: accentSubtle ?? this.accentSubtle,
      secondaryAccent: secondaryAccent ?? this.secondaryAccent,
      secondaryAccentMuted: secondaryAccentMuted ?? this.secondaryAccentMuted,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      info: info ?? this.info,
    );
  }

  @override
  MotornautsThemeColors lerp(
    ThemeExtension<MotornautsThemeColors>? other,
    double t,
  ) {
    if (other is! MotornautsThemeColors) {
      return this;
    }
    return MotornautsThemeColors(
      page: Color.lerp(page, other.page, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      elevated: Color.lerp(elevated, other.elevated, t)!,
      overlay: Color.lerp(overlay, other.overlay, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textOnAccent: Color.lerp(textOnAccent, other.textOnAccent, t)!,
      borderSubtle: Color.lerp(borderSubtle, other.borderSubtle, t)!,
      borderDefault: Color.lerp(borderDefault, other.borderDefault, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentHover: Color.lerp(accentHover, other.accentHover, t)!,
      accentMuted: Color.lerp(accentMuted, other.accentMuted, t)!,
      accentSubtle: Color.lerp(accentSubtle, other.accentSubtle, t)!,
      secondaryAccent: Color.lerp(secondaryAccent, other.secondaryAccent, t)!,
      secondaryAccentMuted:
          Color.lerp(secondaryAccentMuted, other.secondaryAccentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

ThemeData buildMotornautsTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors = dark ? _darkColors : _lightColors;
  final colorScheme = _colorScheme(brightness, colors);
  final baseTextTheme = (dark
          ? Typography.material2021().white
          : Typography.material2021().black)
      .apply(bodyColor: colors.textPrimary, displayColor: colors.textPrimary)
      .copyWith(
        headlineSmall: TextStyle(
          color: colors.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        titleSmall: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: TextStyle(color: colors.textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: colors.textSecondary, fontSize: 12),
        labelLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        labelMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    extensions: <ThemeExtension<dynamic>>[colors],
    scaffoldBackgroundColor: colors.page,
    textTheme: baseTextTheme,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: colors.page,
      foregroundColor: colors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: baseTextTheme.titleLarge,
      iconTheme: IconThemeData(color: colors.textPrimary),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.borderDefault),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colors.borderDefault,
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: TextStyle(color: colors.textSecondary),
      hintStyle: TextStyle(color: colors.textTertiary),
      errorStyle: TextStyle(color: colors.danger, fontWeight: FontWeight.w600),
      prefixIconColor: colors.textSecondary,
      suffixIconColor: colors.textSecondary,
      border: _inputBorder(colors.borderDefault),
      enabledBorder: _inputBorder(colors.borderDefault),
      disabledBorder: _inputBorder(colors.borderSubtle),
      focusedBorder: _inputBorder(colors.accent, width: 1.6),
      errorBorder: _inputBorder(colors.danger),
      focusedErrorBorder: _inputBorder(colors.danger, width: 1.6),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.accentMuted,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        return IconThemeData(
          color:
              states.contains(WidgetState.selected)
                  ? colors.accent
                  : colors.textSecondary,
          size: 24,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        return TextStyle(
          color:
              states.contains(WidgetState.selected)
                  ? colors.accent
                  : colors.textSecondary,
          fontSize: 12,
          fontWeight:
              states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w600,
        );
      }),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: colors.accent,
      dividerColor: colors.borderDefault,
      labelColor: colors.accent,
      unselectedLabelColor: colors.textSecondary,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.elevated;
          }
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered)) {
            return colors.accentHover;
          }
          return colors.accent;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textTertiary;
          }
          return colors.textOnAccent;
        }),
        overlayColor: WidgetStatePropertyAll(colors.accentSubtle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textTertiary;
          }
          return colors.accent;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          return BorderSide(
            color:
                states.contains(WidgetState.disabled)
                    ? colors.borderSubtle
                    : colors.borderStrong,
          );
        }),
        overlayColor: WidgetStatePropertyAll(colors.accentSubtle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textTertiary;
          }
          return colors.accent;
        }),
        overlayColor: WidgetStatePropertyAll(colors.accentSubtle),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size.square(44)),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return colors.textTertiary;
          }
          return colors.textSecondary;
        }),
        overlayColor: WidgetStatePropertyAll(colors.accentSubtle),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.elevated;
        }
        if (states.contains(WidgetState.selected)) {
          return colors.accent;
        }
        return colors.surface;
      }),
      checkColor: WidgetStatePropertyAll(colors.textOnAccent),
      side: BorderSide(color: colors.borderStrong),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: colors.accent,
      inactiveTrackColor: colors.accentMuted,
      thumbColor: colors.accent,
      overlayColor: colors.accentMuted,
      valueIndicatorColor: colors.elevated,
      valueIndicatorTextStyle: TextStyle(color: colors.textPrimary),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        side: WidgetStatePropertyAll(BorderSide(color: colors.borderDefault)),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accentMuted;
          }
          return colors.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colors.accent;
          }
          return colors.textSecondary;
        }),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: colors.accent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colors.elevated,
      contentTextStyle: TextStyle(color: colors.textPrimary),
      actionTextColor: colors.accent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      titleTextStyle: baseTextTheme.titleLarge,
      contentTextStyle: baseTextTheme.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: colors.surface,
      modalBackgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: colors.textSecondary,
      textColor: colors.textPrimary,
      subtitleTextStyle: baseTextTheme.bodySmall,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      minLeadingWidth: 28,
      minVerticalPadding: 10,
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        border: _inputBorder(colors.borderDefault),
        enabledBorder: _inputBorder(colors.borderDefault),
        focusedBorder: _inputBorder(colors.accent, width: 1.6),
      ),
    ),
  );
}

const _darkColors = MotornautsThemeColors(
  page: Color(0xFF0B0B0C),
  subtle: Color(0xFF111113),
  surface: Color(0xFF171719),
  elevated: Color(0xFF202024),
  overlay: Color(0xBF000000),
  textPrimary: Color(0xFFF6F1E8),
  textSecondary: Color(0xFFA9A196),
  textTertiary: Color(0xFF746D65),
  textOnAccent: Color(0xFF120B03),
  borderSubtle: Color(0x0FFFFFFF),
  borderDefault: Color(0x1AFFFFFF),
  borderStrong: Color(0x2EFFFFFF),
  accent: Color(0xFFD98A21),
  accentHover: Color(0xFFF0A23A),
  accentMuted: Color(0x29D98A21),
  accentSubtle: Color(0x14D98A21),
  secondaryAccent: Color(0xFF6F767F),
  secondaryAccentMuted: Color(0x1F6F767F),
  success: Color(0xFF21E07A),
  warning: Color(0xFFFFB400),
  danger: Color(0xFFFF3D55),
  info: Color(0xFF5BC8FF),
);

const _lightColors = MotornautsThemeColors(
  page: Color(0xFFF7F3EA),
  subtle: Color(0xFFEDE6DA),
  surface: Color(0xFFFFFCF5),
  elevated: Color(0xFFFFFFFF),
  overlay: Color(0xBF000000),
  textPrimary: Color(0xFF15120E),
  textSecondary: Color(0xFF5D554B),
  textTertiary: Color(0xFF8C8276),
  textOnAccent: Color(0xFFFFFBF4),
  borderSubtle: Color(0xFFE8DFD2),
  borderDefault: Color(0xFFDDD2C2),
  borderStrong: Color(0xFFCBBBA5),
  accent: Color(0xFFA65F12),
  accentHover: Color(0xFF8F4E0B),
  accentMuted: Color(0x26A65F12),
  accentSubtle: Color(0x14A65F12),
  secondaryAccent: Color(0xFF383B40),
  secondaryAccentMuted: Color(0x1F383B40),
  success: Color(0xFF21E07A),
  warning: Color(0xFFFFB400),
  danger: Color(0xFFFF3D55),
  info: Color(0xFF5BC8FF),
);

ColorScheme _colorScheme(Brightness brightness, MotornautsThemeColors colors) {
  return ColorScheme(
    brightness: brightness,
    primary: colors.accent,
    onPrimary: colors.textOnAccent,
    primaryContainer: colors.accentMuted,
    onPrimaryContainer: colors.textPrimary,
    secondary: colors.secondaryAccent,
    onSecondary:
        brightness == Brightness.light ? Colors.white : colors.textPrimary,
    secondaryContainer: colors.secondaryAccentMuted,
    onSecondaryContainer: colors.textPrimary,
    tertiary: colors.info,
    onTertiary:
        brightness == Brightness.light
            ? colors.textOnAccent
            : colors.textPrimary,
    tertiaryContainer: colors.statusBackground(colors.info),
    onTertiaryContainer: colors.textPrimary,
    error: colors.danger,
    onError: brightness == Brightness.light ? Colors.white : colors.textPrimary,
    errorContainer: colors.statusBackground(colors.danger),
    onErrorContainer: colors.textPrimary,
    surface: colors.surface,
    onSurface: colors.textPrimary,
    surfaceDim: colors.subtle,
    surfaceBright: colors.elevated,
    surfaceContainerLowest: colors.page,
    surfaceContainerLow: colors.subtle,
    surfaceContainer: colors.surface,
    surfaceContainerHigh: colors.elevated,
    surfaceContainerHighest: colors.elevated,
    onSurfaceVariant: colors.textSecondary,
    outline: colors.borderStrong,
    outlineVariant: colors.borderDefault,
    shadow: Colors.black,
    scrim: colors.overlay,
    inverseSurface: colors.textPrimary,
    onInverseSurface: colors.page,
    inversePrimary: colors.accentHover,
    surfaceTint: Colors.transparent,
  );
}

OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: color, width: width),
  );
}
