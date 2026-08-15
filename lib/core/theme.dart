import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens + both themes. Screens should read colors, radii and spacing
/// from here (or from `Theme.of(context)`) rather than hardcoding hex/px, so a
/// brand change is a one-file change.
class RatrooTheme {
  // ---- Brand -------------------------------------------------------------
  // Saffron carries the app's chrome: the wordmark, the selected tab, the
  // primary action, a departure time. Mode colours below carry *data* and are
  // deliberately a separate set — chrome and data must never be the same hue,
  // or a bus card and a Save button read as the same kind of thing.
  //
  // The blue this replaces was the one colour on a near-black screen, so the
  // app read as generic. Saffron on a warm ground is West Bengal's own palette
  // and leaves the cool mode colours free to mean something.
  static const Color primaryColor = Color(0xFFFF9933); // Saffron — filled
  static const Color primaryDeep = Color(0xFFE07C1A); // pressed
  static const Color onPrimaryColor = Color(0xFF4C2700); // text on saffron
  static const Color accentColor = Color(0xFFFFC08D); // saffron for text/icons on dark
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
  // An elevation ramp, not one card colour.
  //
  // The dark theme was a #0F1115 ground with a single #1C1F26 card and a 6%
  // border. On a phone that is two near-identical blacks and an invisible
  // hairline, so nothing separated from anything and the screen read as one
  // flat sheet. Five steps, warm-biased toward the saffron, so a card sits on
  // the page and a sheet sits on the card without either needing a shadow.
  static const Color darkBackground = Color(0xFF111316);
  static const Color darkSurfaceLow = Color(0xFF1A1C1F);
  static const Color darkSurface = Color(0xFF1E2023);
  static const Color darkSurfaceHigh = Color(0xFF282A2D);
  static const Color darkSurfaceVariant = Color(0xFF333538);

  /// Warm brown rather than white-at-8%: a hairline you can actually see.
  static const Color darkOutline = Color(0xFF554336);

  static const Color lightBackground = Color(0xFFFAF8F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF4EFE9);
  static const Color lightOutline = Color(0xFFE7DED3);

  /// Per-mode colour for route lines, leg bars and mode dots. Keyed by the
  /// API's routeType so it matches `<routeType>_STOP` categories elsewhere.
  ///
  /// Bus carries its own blue rather than aliasing the brand colour. It used
  /// to be `primaryColor`, which was fine while that was transit blue and
  /// wrong the moment the brand went saffron: every bus tile turned the same
  /// hue as the Save button and the selected tab, and a mode stopped being
  /// distinguishable from an action.
  static const Map<String, Color> modeColors = {
    'bus': Color(0xFF3B82F6),
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

  /// Falls back to the walk grey, not to the brand colour: an unrecognised
  /// mode is unknown, and painting it saffron would claim it is the app's
  /// primary one.
  static Color modeColor(String? mode) =>
      modeColors[mode?.toLowerCase()] ?? const Color(0xFF94A3B8);

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
  // Space Grotesk for display/headline/title — a grotesk with squared-off
  // terminals that reads as signage rather than as another geometric app face.
  // Inter for body, because it was built for small sizes.
  //
  // JetBrains Mono for anything that is a *figure*: departure times, route
  // codes, distances, counts. See [mono]. A timetable app aligns numerals in
  // columns all day, and a proportional face makes 14:05 and 14:15 different
  // widths — the column jitters as the minute ticks over.
  static TextTheme _textTheme(Color onSurface) {
    final muted = onSurface.withValues(alpha: 0.68);
    return TextTheme(
      displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1.2, height: 1.05, color: onSurface),
      displayMedium: GoogleFonts.spaceGrotesk(
          fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.1, color: onSurface),
      displaySmall: GoogleFonts.spaceGrotesk(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.8, height: 1.15, color: onSurface),
      headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: onSurface),
      headlineSmall: GoogleFonts.spaceGrotesk(
          fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: onSurface),
      titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: onSurface),
      titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: onSurface),
      titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5, color: onSurface),
      bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.5, color: muted),
      bodySmall: GoogleFonts.inter(fontSize: 12, height: 1.45, color: muted),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: onSurface),
      // Labels are where the eyebrow text lives — "PUBLISHED", "2 MIN".
      labelMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.2, color: muted),
      labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.6, color: muted),
    );
  }

  /// The figure face. Use for departure times, countdowns, route codes,
  /// distances and counts — anything that lines up in a column or ticks over
  /// in place. Tabular by construction, so nothing reflows as digits change.
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double letterSpacing = 0,
  }) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static ThemeData _base(ColorScheme scheme, Color scaffold) {
    final onSurface = scheme.onSurface;
    final text = _textTheme(onSurface);
    final isDark = scheme.brightness == Brightness.dark;
    // The scheme's own outline, not white-at-8%. A card edge drawn as 8% white
    // on a #0F1115 ground is invisible on a phone in daylight, which is why
    // every surface used to melt into the page.
    final hairline = scheme.outline.withValues(alpha: isDark ? 0.85 : 1.0);

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
        // A step above the cards it floats over, so the bar reads as chrome
        // sitting on the page rather than as one more card.
        backgroundColor: isDark ? darkSurfaceHigh : lightSurface,
        surfaceTintColor: Colors.transparent,
        // Solid saffron, not a 24% wash. The selected tab is the one place
        // the brand colour should be at full strength.
        indicatorColor: scheme.primary,
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
            // On the solid saffron pill the glyph has to invert; saffron on
            // saffron would be a blank pill.
            color: s.contains(WidgetState.selected)
                ? scheme.onPrimary
                : onSurface.withValues(alpha: 0.6),
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
          onPrimary: onPrimaryColor,
          // The lighter saffron. `primary` is the filled-button colour and is
          // too heavy for a run of text; this is the one that clears 4.5:1 as
          // a label on the dark ground.
          primaryContainer: primaryColor,
          onPrimaryContainer: onPrimaryColor,
          secondary: accentColor,
          onSecondary: onPrimaryColor,
          tertiary: secondaryColor,
          onTertiary: Colors.white,
          surface: darkSurface,
          onSurface: Color(0xFFE2E2E6),
          surfaceContainerLow: darkSurfaceLow,
          surfaceContainer: darkSurface,
          surfaceContainerHigh: darkSurfaceHigh,
          surfaceContainerHighest: darkSurfaceVariant,
          outline: darkOutline,
        ),
        darkBackground,
      );

  static ThemeData get lightTheme => _base(
        const ColorScheme.light(
          primary: primaryDeep,
          onPrimary: Colors.white,
          primaryContainer: primaryColor,
          onPrimaryContainer: onPrimaryColor,
          secondary: accentDeep,
          onSecondary: Colors.white,
          tertiary: secondaryColor,
          onTertiary: Colors.white,
          surface: lightSurface,
          // Warm near-black rather than slate: a cool grey text on a warm
          // ground is the tell that a palette was assembled from two sources.
          onSurface: Color(0xFF1C1714),
          surfaceContainerLow: Color(0xFFFCFAF7),
          surfaceContainer: lightSurface,
          surfaceContainerHigh: lightSurfaceVariant,
          surfaceContainerHighest: Color(0xFFEDE6DD),
          outline: lightOutline,
        ),
        lightBackground,
      );
}
