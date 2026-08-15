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

  /// The generated illustration per mode.
  ///
  /// This used to be four `hero_*.jpg` stock photographs whose origin was
  /// never confirmed — `assets/README.md` carried that as a release blocker
  /// for three sessions. The generated set replaces them and they are deleted.
  /// (`hero_bus.jpg` survives, but only as `BusBanner`'s fallback when the
  /// video cannot decode.)
  static const _illustrations = {
    'bus': 'assets/brand/mode_bus.png',
    'rail': 'assets/brand/mode_rail.png',
    'ferry': 'assets/brand/mode_ferry.png',
    'tram': 'assets/brand/mode_tram.png',
  };

  /// True when we hold artwork for this mode. Metro has none, because it has
  /// no data either.
  static bool hasPhoto(String? mode) =>
      _illustrations.containsKey(mode?.toLowerCase());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = _illustrations[mode.toLowerCase()];
    if (art == null) return const SizedBox.shrink();
    final colour = RatrooTheme.modeColor(mode);

    // Words left, vehicle right, on a wash of the mode's own colour.
    //
    // This used to be a photograph filling the banner under a black scrim.
    // The art is now a transparent cut-out with no scene behind it, so
    // `cover` would crop the nose off and the scrim would darken nothing —
    // a scrim exists to rescue white text from a bright sky, and there is no
    // sky. The colour wash does that job and names the mode at the same time.
    return Container(
      height: 168,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color.alphaBlend(colour.withValues(alpha: 0.30), theme.colorScheme.surface),
            Color.alphaBlend(colour.withValues(alpha: 0.14), theme.colorScheme.surface),
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: RatrooTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(RatrooTheme.space3),
            child: Image.asset(
              art,
              height: 132,
              fit: BoxFit.contain,
              semanticLabel: '$title, illustration',
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
