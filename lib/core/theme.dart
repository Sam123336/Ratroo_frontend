import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens + both themes. Screens should read colors, radii and spacing
/// from here (or from `Theme.of(context)`) rather than hardcoding hex/px, so a
/// brand change is a one-file change.
class RatrooTheme {
  // ---- Brand -------------------------------------------------------------
  // Transit blue carries structure — route lines, active nav, primary actions.
  // Orange is the brand mark's colour and is reserved for things that want a
  // tap: CTAs, live badges, the selected mode. Using it for anything else
  // spends the only colour that stands out.
  static const Color primaryColor = Color(0xFF2563EB); // Transit Blue
  static const Color primaryDeep = Color(0xFF1D4ED8); // pressed / gradients
  static const Color accentColor = Color(0xFFEA580C); // Ratroo Orange
  static const Color accentDeep = Color(0xFFC2410C); // pressed
  static const Color secondaryColor = Color(0xFF0891B2); // secondary lines/legs

  // ---- Confidence scale --------------------------------------------------
  // `*Fill` for gauges/badges on any background; `*Text` is the darkened pair
  // that clears 4.5:1 on light surfaces. Never use a Fill colour for body text.
  static const Color confidenceHighFill = Color(0xFF00B95C);
  static const Color confidenceHighText = Color(0xFF017A3E);
  static const Color confidenceMedFill = Color(0xFFFBBC04);
  static const Color confidenceMedText = Color(0xFF8A6100);
  static const Color confidenceLowFill = Color(0xFFFC413D);
  static const Color confidenceLowText = Color(0xFFC0201D);

  /// Fill/text pair for a 0..1 confidence score.
  static (Color fill, Color text) confidence(double score) => score >= 0.8
      ? (confidenceHighFill, confidenceHighText)
      : score >= 0.5
          ? (confidenceMedFill, confidenceMedText)
          : (confidenceLowFill, confidenceLowText);

  // ---- Surfaces ----------------------------------------------------------
  static const Color darkBackground = Color(0xFF0F1115);
  static const Color darkSurface = Color(0xFF1C1F26);
  static const Color darkSurfaceVariant = Color(0xFF282C35);

  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F5FD);

  /// Per-mode colour for route lines, leg bars and mode dots. Keyed by the
  /// API's routeType so it matches `<routeType>_STOP` categories elsewhere.
  static const Map<String, Color> modeColors = {
    'bus': primaryColor,
    'rail': Color(0xFF7C3AED),
    'ferry': secondaryColor,
    'tram': Color(0xFFDB2777),
    'metro': Color(0xFF059669),
    // Amber: the colour an auto actually is on a West Bengal road, and far
    // enough from bus blue and tram pink to stay distinct in a list.
    'auto': Color(0xFFD97706),
    'shared_auto': Color(0xFFB45309),
    'walk': Color(0xFF64748B),
  };

  static Color modeColor(String? mode) =>
      modeColors[mode?.toLowerCase()] ?? primaryColor;

  // ---- Scales ------------------------------------------------------------
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double radiusPill = 999;

  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;

  /// Soft, wide, low-opacity shadow — reads as depth without a grey halo.
  static List<BoxShadow> cardShadow(Brightness b) => b == Brightness.dark
      ? const [BoxShadow(color: Color(0x66000000), blurRadius: 24, offset: Offset(0, 8))]
      : const [BoxShadow(color: Color(0x141B2A4E), blurRadius: 24, offset: Offset(0, 8))];

  // ---- Typography --------------------------------------------------------
  // Outfit for display/headline/title (geometric, brand voice),
  // Inter for body/label (built for small sizes).
  static TextTheme _textTheme(Color onSurface) {
    final muted = onSurface.withValues(alpha: 0.68);
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
          fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.1, color: onSurface),
      displayMedium: GoogleFonts.outfit(
          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.15, color: onSurface),
      displaySmall: GoogleFonts.outfit(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.6, height: 1.2, color: onSurface),
      headlineMedium: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: onSurface),
      headlineSmall: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: onSurface),
      titleLarge: GoogleFonts.outfit(
          fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: onSurface),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5, color: onSurface),
      bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, color: muted),
      bodySmall: GoogleFonts.inter(fontSize: 12, height: 1.45, color: muted),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      labelMedium: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: muted),
      labelSmall: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: muted),
    );
  }

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    final onSurface = scheme.onSurface;
    final text = _textTheme(onSurface);
    final isDark = scheme.brightness == Brightness.dark;
    final hairline = onSurface.withValues(alpha: isDark ? 0.12 : 0.08);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      primaryColor: scheme.primary,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: space6),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: hairline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? darkSurfaceVariant : lightSurface,
        hintStyle: text.bodyMedium,
        contentPadding: const EdgeInsets.symmetric(horizontal: space6, vertical: space4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: BorderSide(color: hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: BorderSide(color: hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusPill),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52), // 48dp+ touch target
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(52),
          elevation: 0,
          textStyle: text.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: hairline),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? darkSurfaceVariant : lightSurfaceVariant,
        side: BorderSide.none,
        labelStyle: text.labelMedium!.copyWith(color: onSurface),
        padding: const EdgeInsets.symmetric(horizontal: space3, vertical: space1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: isDark ? darkSurface : lightSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.24 : 0.12),
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusPill)),
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? text.labelSmall!.copyWith(color: scheme.primary, letterSpacing: 0.2)
              : text.labelSmall!,
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 24,
            color: s.contains(WidgetState.selected) ? scheme.primary : onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? darkSurface : lightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? darkSurfaceVariant : const Color(0xFF1C1F26),
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: hairline,
      ),
    );
  }

  static ThemeData get darkTheme => _base(
        const ColorScheme.dark(
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: accentColor,
          onSecondary: Colors.white,
          tertiary: secondaryColor,
          onTertiary: Colors.white,
          surface: darkSurface,
          onSurface: Color(0xFFEDF0F6),
          surfaceContainerHighest: darkSurfaceVariant,
          outline: Color(0xFF3A3F4B),
        ),
        darkBackground,
      );

  static ThemeData get lightTheme => _base(
        const ColorScheme.light(
          primary: primaryColor,
          onPrimary: Colors.white,
          secondary: accentColor,
          onSecondary: Colors.white,
          tertiary: secondaryColor,
          onTertiary: Colors.white,
          surface: lightSurface,
          // Slate 900 — the mockups' near-black, 16:1 on white.
          onSurface: Color(0xFF0F172A),
          surfaceContainerHighest: lightSurfaceVariant,
          outline: Color(0xFFE4ECFC),
        ),
        lightBackground,
      );
}
