import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;

  /// Fill opacity. 0.88 reads as frosted over a map; pass 1.0 for a solid card.
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final Border? border;
  final Color? color;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10.0,
    this.opacity = 0.88,
    this.borderRadius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.border,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Frosted *surface*, not a black/white tint. The old default (black @ 15%
    // over an opaque scaffold) flattened to solid #D9D9D9 — a grey slab, not glass.
    final baseColor = color ?? theme.colorScheme.surface;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(RatrooTheme.radiusLg);

    return Container(
      margin: margin,
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: effectiveBorderRadius,
        boxShadow: RatrooTheme.cardShadow(theme.brightness),
      ),
      child: ClipRRect(
        borderRadius: effectiveBorderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: opacity),
              borderRadius: effectiveBorderRadius,
              border: border ??
                  Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.07),
                    width: 1.0,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
