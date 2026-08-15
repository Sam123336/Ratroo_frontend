import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../core/app_icons.dart';
import '../core/transit_icons.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/coverage_summary.dart';

/// What runs where the rider is, as one card.
///
/// Replaces a row of four photo circles. The circles gave every mode the same
/// weight whether it had 2,727 routes or six, said nothing about the city they
/// belonged to, and needed a photograph per mode that the app had to ship.
/// One card names the place and lists what actually runs there, largest first.
///
/// Only modes with routes appear. A mode we hold nothing for is left out
/// rather than shown as a zero — an empty row reads as a broken network, not
/// as missing data.
class CityCard extends StatelessWidget {
  /// The city the rider is in, when a nearby stop named one.
  final String? city;

  final CoverageSummary coverage;

  /// When the data was last touched by ingestion, when we know.
  final DateTime? updatedAt;

  /// Opens the operator list — who runs these services.
  final VoidCallback? onOperators;

  const CityCard({
    super.key,
    required this.city,
    required this.coverage,
    this.updatedAt,
    this.onOperators,
  });

  static const _label = <String, String>{
    'bus': 'Bus',
    'rail': 'Train',
    'metro': 'Metro',
    'ferry': 'Ferry',
    'tram': 'Tram',
    'auto': 'Auto',
    'shared_auto': 'Shared auto',
  };

  /// The city the rider is standing in, when we hold counts for it.
  ///
  /// Matched on name because that is all the two sides share — the coverage
  /// endpoint groups on `stops.city`, and the area comes from the nearest
  /// stop's own city field.
  CityCoverage? get _localCity {
    final here = city?.trim().toLowerCase();
    if (here == null || here.isEmpty) return null;
    for (final entry in coverage.byCity) {
      if (entry.city.trim().toLowerCase() == here) return entry;
    }
    return null;
  }

  /// Busiest mode first — a rider scanning this wants the one they are most
  /// likely to catch at the top, not alphabetical order.
  ///
  /// Scoped to their city when we have it: trams and ferries run in Kolkata
  /// and nowhere else, so a state-wide list tells someone in Bardhaman they
  /// can catch a tram.
  List<ModeCoverage> get _modes {
    final source = _localCity?.byMode ?? coverage.byMode;
    final rows = source.where((mode) => mode.routeCount > 0).toList()
      ..sort((a, b) => b.routeCount.compareTo(a.routeCount));
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = _localCity;
    final modes = _modes;
    if (modes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No "View map" button beside the heading: the grid's last cell is
        // that action. A long place name wrapped to two lines and collided
        // with the button, and it was the same link twice either way.
        Padding(
          padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
          child: Text(
            'Travel across ${local?.city ?? city ?? coverage.region ?? 'your area'}',
            style: theme.textTheme.headlineSmall,
          ),
        ),
        // A two-column grid, not a horizontal strip.
        //
        // The strip clipped its third tile mid-word at the viewport edge, so
        // "8 routes / 25 stations" read as "8 route… / 25 stati…" — a
        // truncation that looks like a rendering fault rather than an
        // invitation to scroll. A grid shows every mode at once, which is
        // four to six tiles in practice, and each gets twice the width.
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: RatrooTheme.space3,
          crossAxisSpacing: RatrooTheme.space3,
          // A fixed tile height, not an aspect ratio. With a ratio the tile
          // grows with the column, so on a tablet or in landscape a 400px-wide
          // cell became a 330px-tall one — a stat tile the height of a card.
          mainAxisExtent: 144,
          children: [
            for (final mode in modes) _ModeRow(mode: mode),
            // The odd-one-out slot. With an odd number of modes the grid
            // leaves a hole, and a map link is a better use of it than air.
            const _ViewMapTile(),
          ],
        ),
      ],
    );
  }
}

/// Fills the grid's trailing cell with the map rather than a gap.
///
/// Outlined and unfilled, where the tiles beside it are filled: it is an
/// action, not a statistic, and drawing it the same way would imply it
/// carries a count too. (Stitch's mock dashes this border. A dash needs a
/// CustomPainter or a package for one tile, and the absent fill already
/// makes the distinction.)
class _ViewMapTile extends StatelessWidget {
  const _ViewMapTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return InkWell(
      borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
      onTap: () => context.go('/nearby'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // The illustration when it is present, the glyph until then.
            //
            // `errorBuilder` is the whole mechanism: the asset is declared in
            // pubspec via the `assets/brand/` directory entry, so dropping the
            // file in is the only step — no code change, no pubspec edit. Until
            // it exists, Flutter raises and this falls back rather than
            // showing a broken-image box.
            Image.asset(
              'assets/brand/tile_map.png',
              height: 44,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => Icon(
                AppIcons.map,
                size: 24,
                color: muted,
              ),
            ),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              'View map',
              style: theme.textTheme.titleSmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// The card's own loading state, drawn from the card's own widgets.
///
/// Home used to draw four grey circles here, left over from when this section
/// was a row of photo circles. The section became a strip of 132×172 cards and
/// the placeholder never followed, so the screen resolved from four circles
/// into three rectangles. `skeletonizer` is in the project precisely so a
/// placeholder cannot drift from the layout it stands in for — this feeds it
/// the real [_ModeRow] and lets it draw the bones.
class CityCardSkeleton extends StatelessWidget {
  const CityCardSkeleton({super.key});

  // Counts are never read: skeletonizer paints bones over the text, and the
  // digits only exist to give those bones the right line box.
  static const _placeholders = [
    ModeCoverage(mode: 'bus', routeCount: 1000, stopCount: 1000),
    ModeCoverage(mode: 'rail', routeCount: 100, stopCount: 100),
    ModeCoverage(mode: 'ferry', routeCount: 10, stopCount: 10),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Skeletonizer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
            child: Text(
              'Travel across your area',
              style: theme.textTheme.headlineSmall,
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            mainAxisSpacing: RatrooTheme.space3,
            crossAxisSpacing: RatrooTheme.space3,
            // A fixed tile height, not an aspect ratio. With a ratio the tile
          // grows with the column, so on a tablet or in landscape a 400px-wide
          // cell became a 330px-tall one — a stat tile the height of a card.
          mainAxisExtent: 144,
            children: [
              for (final mode in _placeholders) _ModeRow(mode: mode),
            ],
          ),
        ],
      ),
    );
  }
}

/// One mode inside the card, tapping through to what is nearby on it.
/// One mode, as a card in the strip.
class _ModeRow extends StatelessWidget {
  final ModeCoverage mode;

  const _ModeRow({required this.mode});

  /// Riders say ghat, not "ferry stop", and station, not "rail stop".
  static const _stopNoun = <String, String>{
    'bus': 'stops',
    'rail': 'stations',
    'metro': 'stations',
    'ferry': 'ghats',
    'tram': 'stops',
    'auto': 'stands',
    'shared_auto': 'stands',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = RatrooTheme.modeColor(mode.mode);
    final label = CityCard._label[mode.mode] ?? mode.mode;

    // The figure leads.
    //
    // The tile used to be a 26px line glyph pinned top-left, a chevron
    // top-right, and the text at the bottom — with the middle third empty.
    // What a rider scans for is "how much bus is there", so the count is set
    // at display size and everything else supports it.
    return InkWell(
      borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
      onTap: () => context.go('/nearby?mode=${mode.mode}'),
      child: Container(
        padding: const EdgeInsets.all(RatrooTheme.space4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // The shared avatar, so the plate here and the circle in a
                // Nearby row can never drift. 44 rather than 34: the mode
                // illustrations are detailed, and ten more pixels is the
                // difference between a vehicle and a smudge.
                ModeAvatar.forMode(mode.mode, size: 44, rounded: true),
                const Spacer(),
                Text(
                  label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(color: colour),
                ),
              ],
            ),
            const Spacer(),
            // Mono, because these line up in a grid and must not jitter as
            // the counts change between regions.
            Text(
              groupedNumber(mode.routeCount),
              style: RatrooTheme.mono(
                size: 27,
                weight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              '${mode.routeCount == 1 ? 'route' : 'routes'}'
              '${mode.stopCount > 0 ? ' · ${groupedNumber(mode.stopCount)} '
                  '${_stopNoun[mode.mode] ?? 'stops'}' : ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
