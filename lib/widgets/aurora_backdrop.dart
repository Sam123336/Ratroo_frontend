import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A lit backdrop for the top of a screen: two soft colour fields behind the
/// content, fading out before the list begins.
///
/// This is where the app's depth comes from today. Real 3D needs model or Rive
/// files the project does not have yet (see `assets/README.md`), and a flat
/// white page under floating cards is what made the UI read as a stack of
/// widgets rather than a designed surface. Layered light is cheap, runs at
/// display rate, and costs nothing on a mid-range Android.
///
/// Painted, not blurred: a `BackdropFilter` over a scrolling list re-rasterises
/// every frame, which is exactly the cost this app cannot afford on the devices
/// most of its riders carry.
class AuroraBackdrop extends StatelessWidget {
  final Widget child;

  /// How far down the screen the light reaches.
  final double height;

  const AuroraBackdrop({super.key, required this.child, this.height = 420});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: height,
          child: IgnorePointer(
            child: CustomPaint(
              painter: _AuroraPainter(
                primary: theme.colorScheme.primary,
                secondary: RatrooTheme.secondaryColor,
                accent: RatrooTheme.accentColor,
                surface: theme.scaffoldBackgroundColor,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color surface;

  _AuroraPainter({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.surface,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;

    // Two overlapping radial fields, offset from each other so the light has a
    // direction instead of sitting symmetrically behind the text.
    void field(Offset centre, double radius, Color colour, double strength) {
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              colour.withValues(alpha: strength),
              colour.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    field(
      Offset(size.width * 0.86, size.height * 0.06),
      size.width * 0.72,
      primary,
      0.20,
    );
    field(
      Offset(size.width * 0.08, size.height * 0.30),
      size.width * 0.60,
      secondary,
      0.14,
    );
    field(
      Offset(size.width * 0.62, size.height * 0.52),
      size.width * 0.52,
      accent,
      0.07,
    );

    // Fade to the page colour before the content starts, so the list scrolls
    // onto a plain surface rather than through a tinted band.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [surface.withValues(alpha: 0), surface],
          stops: const [0.55, 1.0],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.primary != primary ||
      old.secondary != secondary ||
      old.accent != accent ||
      old.surface != surface;
}
