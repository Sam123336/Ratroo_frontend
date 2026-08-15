import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/theme.dart';

/// The animated bus banner on the home screen.
///
/// Full width and given real height. It first went in the header at 44px in
/// place of the logo, where a wide landscape scene read as a stray sticker and
/// left the app with no mark at all — an animation needs room or it is just
/// noise in a corner.
///
/// Falls back to the still photograph of the same bus — not to a blank space —
/// while the video loads, if decoding fails, and whenever the rider has asked
/// the system to reduce motion. The banner is always there; only the motion is
/// conditional.
///
/// Silent and looping by design: a banner that makes noise is a bug, and one
/// that plays once then freezes on an arbitrary frame looks broken.
class BusBanner extends StatefulWidget {
  final double height;

  /// Square it off when the banner is acting as a backdrop for something else.
  final BorderRadius? borderRadius;

  const BusBanner({super.key, this.height = 150, this.borderRadius});

  static const _asset = 'assets/brand/bus_animation.mp4';
  /// Shown while the video loads, if decoding fails, and whenever the rider
  /// has asked the system to reduce motion.
  ///
  /// Was `hero_bus.jpg`, a stock photograph with no confirmed origin. The
  /// generated cut-out replaces it — and unlike the photo it is drawn
  /// `contain` on a tinted ground, because it has no background of its own.
  static const _fallback = 'assets/brand/mode_bus.png';

  @override
  State<BusBanner> createState() => _BusBannerState();
}

class _BusBannerState extends State<BusBanner> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Started here rather than in initState because the decision depends on
    // MediaQuery: with animations off we never pay for a decoder at all.
    if (_controller == null && !MediaQuery.disableAnimationsOf(context)) {
      _start();
    }
  }

  Future<void> _start() async {
    final controller = VideoPlayerController.asset(BusBanner._asset);
    _controller = controller;

    try {
      await controller.initialize();
      await controller.setVolume(0);
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() {});
    } catch (error) {
      // Every failure lands here: a missing native plugin registration after
      // adding video_player without a full rebuild, a codec the device cannot
      // decode, a corrupt asset. The mark is brand, so it always renders —
      // the static logo takes over and nothing is shown broken.
      debugPrint('BusBanner: falling back to the static logo ($error)');

      // Release the half-built controller rather than leaving a dead decoder
      // attached for the life of the screen.
      _controller = null;
      unawaited(controller.dispose().catchError((_) {}));

      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready =
        !_failed && controller != null && controller.value.isInitialized;

    return Semantics(
      label: 'Travel across West Bengal with Ratroo',
      child: ExcludeSemantics(
        child: ClipRRect(
          borderRadius:
              widget.borderRadius ??
              BorderRadius.circular(RatrooTheme.radiusXl),
          child: SizedBox(
            height: widget.height,
            width: double.infinity,
            child: ready
                // Cover, not contain: the banner is a fixed shape in the
                // layout, and letterboxing it would put grey bars inside a
                // rounded card.
                ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: controller.value.size.width,
                      height: controller.value.size.height,
                      child: VideoPlayer(controller),
                    ),
                  )
                : ColoredBox(
                    color: RatrooTheme.modeColor('bus').withValues(alpha: 0.16),
                    child: Padding(
                      padding: const EdgeInsets.all(RatrooTheme.space3),
                      child: Image.asset(
                        BusBanner._fallback,
                        fit: BoxFit.contain,
                        // The asset could go missing too; a tinted panel is a
                        // better last resort than a broken-image box.
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
