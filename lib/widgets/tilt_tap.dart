import 'package:flutter/material.dart';

/// Press feedback that tips the card away from the finger.
///
/// A real perspective matrix rather than a flat scale: the far edge shrinks
/// more than the near one, which is what makes a surface read as a solid
/// object being pushed rather than a rectangle getting smaller.
///
/// The transform never changes the widget's layout bounds, so nothing around
/// it moves — a scale that reflows its neighbours is the usual way this trick
/// goes wrong.
class TiltTap extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  const TiltTap({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<TiltTap> createState() => _TiltTapState();
}

class _TiltTapState extends State<TiltTap> {
  bool _pressed = false;

  /// Where on the card the finger landed, in the range -1..1 on each axis, so
  /// the tilt leans towards the touch.
  Alignment _origin = Alignment.center;

  void _press(bool down, [Offset? local, Size? size]) {
    if (down && local != null && size != null && size.width > 0 && size.height > 0) {
      _origin = Alignment(
        (local.dx / size.width) * 2 - 1,
        (local.dy / size.height) * 2 - 1,
      );
    }
    setState(() => _pressed = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);

    // Reduce-motion still needs press feedback, just not a moving one.
    final matrix = Matrix4.identity();
    if (_pressed && !reduced) {
      matrix
        // Perspective: without this the rotations are a plain skew.
        ..setEntry(3, 2, 0.0012)
        ..rotateX(_origin.y * -0.06)
        ..rotateY(_origin.x * 0.06)
        ..scaleByDouble(0.97, 0.97, 1, 1);
    } else if (_pressed) {
      matrix.scaleByDouble(0.98, 0.98, 1, 1);
    }

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (details) => _press(true, details.localPosition, context.size),
      onTapUp: (_) => _press(false),
      onTapCancel: () => _press(false),
      child: AnimatedContainer(
        // 140ms in, so the press is felt within the 150ms budget.
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        transform: matrix,
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(borderRadius: widget.borderRadius),
        child: widget.child,
      ),
    );
  }
}
