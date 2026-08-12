import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_icons.dart';
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

  static const _icon = <String, IconData>{
    'bus': AppIcons.bus,
    'rail': AppIcons.rail,
    'metro': AppIcons.metro,
    'ferry': AppIcons.ferry,
    'tram': AppIcons.tram,
    'auto': AppIcons.auto,
    'shared_auto': AppIcons.sharedAuto,
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
        Padding(
          padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Travel across ${local?.city ?? city ?? coverage.region ?? 'your area'}',
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              TextButton(
                onPressed: () => context.push('/nearby'),
                child: const Text('View map'),
              ),
            ],
          ),
        ),
        // Side by side rather than stacked: four modes read as a set of
        // choices this way, and each is one tap. The vertical list made the
        // card the tallest thing on the screen for four numbers.
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.zero,
            itemCount: modes.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: RatrooTheme.space3),
            itemBuilder: (context, index) => _ModeRow(mode: modes[index]),
          ),
        ),
      ],
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

    return InkWell(
      borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
      onTap: () => context.push('/nearby?mode=${mode.mode}'),
      child: Container(
        width: 132,
        padding: const EdgeInsets.all(RatrooTheme.space4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(CityCard._icon[mode.mode], size: 26, color: colour),
                const Spacer(),
                Icon(
                  AppIcons.chevron,
                  size: 15,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
                ),
              ],
            ),
            const SizedBox(height: RatrooTheme.space3),
            Text(
              CityCard._label[mode.mode] ?? mode.mode,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: groupedNumber(mode.routeCount),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colour,
                      fontWeight: FontWeight.w700,
                      // Tabular so the figures line up across the strip.
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  TextSpan(
                    text: ' ${mode.routeCount == 1 ? 'route' : 'routes'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (mode.stopCount > 0)
              Text(
                '${groupedNumber(mode.stopCount)} '
                '${_stopNoun[mode.mode] ?? 'stops'}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
