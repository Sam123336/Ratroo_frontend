import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Photo banner naming the mode you are browsing, with a one-line summary.
///
/// A list of stop names is hard to place at a glance; a photograph of the
/// vehicle says "you are looking at ferries" before any text is read. Used on
/// the mode-filtered Nearby screens, where the whole list is one mode.
class ModeHero extends StatelessWidget {
  /// API route type: bus, rail, ferry, tram.
  final String mode;
  final String title;

  /// One line under the title — how many stops, how far we looked.
  final String? subtitle;

  const ModeHero({super.key, required this.mode, required this.title, this.subtitle});

  static const _photos = {
    'bus': 'assets/brand/hero_bus.jpg',
    'rail': 'assets/brand/hero_rail.jpg',
    'ferry': 'assets/brand/hero_ferry.jpg',
    'tram': 'assets/brand/hero_tram.jpg',
  };

  /// True when we hold a photograph for this mode. Metro has none, because it
  /// has no data either.
  static bool hasPhoto(String? mode) => _photos.containsKey(mode?.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = _photos[mode.toLowerCase()];
    if (photo == null) return const SizedBox.shrink();

    return SizedBox(
      // Fixed 32:14, matching the asset, so the text below never jumps once
      // the image decodes.
      height: 168,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            photo,
            fit: BoxFit.cover,
            semanticLabel: '$title, photograph',
            errorBuilder: (_, _, _) => ColoredBox(color: RatrooTheme.modeColor(mode)),
          ),
          // Scrim, not decoration: white text over a bright sky fails contrast
          // outright. Darkest at the bottom where the words sit.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A000000), Color(0xB3000000)],
                stops: [0.35, 1],
              ),
            ),
          ),
          Positioned(
            left: RatrooTheme.space4,
            right: RatrooTheme.space4,
            bottom: RatrooTheme.space4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      // 0.9 white on the scrim clears 4.5:1; the theme's muted
                      // body colour does not.
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
