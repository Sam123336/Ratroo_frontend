import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/api_providers.dart';
import '../models/coverage_summary.dart';
import '../models/place.dart';
import '../services/nearby_service.dart';
import '../models/route.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../widgets/aurora_backdrop.dart';
import '../widgets/glass_container.dart';
import '../widgets/tilt_tap.dart';
import '../core/app_icons.dart';

// Stops around wherever the user actually is, widening the search until it
// finds some. In rural West Bengal the nearest stop can be 10 km away.
final homeNearbyStationsProvider =
    FutureProvider.autoDispose<ApiResponse<NearbyResult>>((ref) async {
      final location = await ref.watch(userLocationProvider.future);
      return ref
          .watch(nearbyServiceProvider)
          .findNearest(location.latitude, location.longitude);
    });

/// The city the user is in, read off the nearest stops rather than a geocoder.
///
/// The header said "Where to, Kolkata?" to everyone, including someone in
/// Bengaluru. Stops carry city/district/state, so the nearest one that has any
/// of them names the area — no extra request, no external geocoding service.
/// Null when the fallback position is in use or no stop names its area: the
/// header then just asks "Where to?" instead of claiming a city.
final homeAreaProvider = Provider.autoDispose<String?>((ref) {
  final location = ref.watch(userLocationProvider).valueOrNull;
  if (location == null || !location.isLive) return null;

  final places =
      ref.watch(homeNearbyStationsProvider).valueOrNull?.data?.places ??
      const <Place>[];
  for (final place in places) {
    final area = place.areaName;
    if (area != null) return area;
  }
  return null;
});

// Fetch saved routes/favorites
final homeSavedRoutesProvider =
    FutureProvider.autoDispose<ApiResponse<List<RouteModel>>>((ref) async {
      final service = ref.watch(favoritesServiceProvider);
      return service.getFavorites();
    });

/// Label per route type the API can report. "rail" is shown as "Train"
/// because that is what people call it; the key stays the API's word.
///
/// Modes with a photo in assets/brand show it; the rest fall back to an icon.
/// Metro has no photo because it has no data either — it never renders.
const _modeChips = <String, (IconData, String)>{
  'bus': (AppIcons.bus, 'Bus'),
  'rail': (AppIcons.rail, 'Train'),
  'ferry': (AppIcons.ferry, 'Ferry'),
  'tram': (AppIcons.tram, 'Tram'),
  'metro': (AppIcons.metro, 'Metro'),
};

const _modePhotos = {'bus', 'rail', 'ferry', 'tram'};

/// Coverage where the user actually is, not a fixed West Bengal claim.
final homeCoverageProvider =
    FutureProvider.autoDispose<ApiResponse<CoverageSummary>>((ref) async {
      final location = await ref.watch(userLocationProvider.future);
      return ref
          .watch(transitServiceProvider)
          .getCoverageSummary(location.latitude, location.longitude);
    });

/// Shown when the device has moved away from the position the screen was built
/// from. The refresh is offered rather than taken: reloading under someone
/// mid-scroll is worse than a stale heading they can see is stale.
class _MovedBanner extends ConsumerWidget {
  final UserLocation to;

  const _MovedBanner({required this.to});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: RatrooTheme.confidenceMedFill.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.myLocation,
            size: 20,
            color: RatrooTheme.confidenceMedText,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have moved since this loaded.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: RatrooTheme.confidenceMedText,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              // Clearing the drift first stops the banner reappearing against
              // the position it was raised about.
              ref.read(locationDriftProvider.notifier).state = null;
              ref.invalidate(userLocationProvider);
              ref.invalidate(homeNearbyStationsProvider);
            },
            child: const Text('Refresh'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Where the app believes the rider is, with a way straight to what is around
/// them. Only rendered when a nearby stop actually named the area — an
/// unlabelled pill claiming a location we guessed would be worse than none.
class _LocationPill extends StatelessWidget {
  final String area;

  const _LocationPill({required this.area});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
      onTap: () => context.push('/nearby'),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space4,
          vertical: RatrooTheme.space2,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.myLocation,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: RatrooTheme.space2),
            Text(
              area,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: RatrooTheme.space1),
            Icon(AppIcons.chevron, size: 14, color: theme.colorScheme.primary),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 180.ms).scale(begin: const Offset(0.94, 0.94));
  }
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: AuroraBackdrop(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              // Location first: pulling to refresh re-read the stops but kept the
              // old position, so a user who had travelled saw the same city
              // however many times they pulled.
              ref.read(locationDriftProvider.notifier).state = null;
              // Forced: the service holds a fix for two minutes, and a deliberate
              // pull should not be answered from that cache.
              await ref
                  .read(locationServiceProvider)
                  .current(forceRefresh: true);
              ref.invalidate(userLocationProvider);
              ref.invalidate(homeNearbyStationsProvider);
              ref.invalidate(homeSavedRoutesProvider);
              ref.invalidate(homeCoverageProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                _buildHeader(context, ref),
                const SizedBox(height: 24),
                _buildSearchBar(context),
                const SizedBox(height: RatrooTheme.space6),
                _buildQuickAccess(context),
                const SizedBox(height: RatrooTheme.space8),
                _buildNearbySection(context, ref),
                const SizedBox(height: RatrooTheme.space8),
                _buildNetworkSection(context, ref),
                const SizedBox(height: RatrooTheme.space8),
                _buildSavedRoutes(context, ref),
                // Clears the floating navigation bar, which now sits over the
                // list instead of below it.
                const SizedBox(height: 96),
              ],
            ),
          ),
        ),
      ),
      // Floats over the list rather than sitting in a slab at the bottom
      // edge. The list reserves 96px at its end so nothing hides under it.
      extendBody: true,
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  /// Names only the modes that actually have routes in the region, and stays
  /// vague while the answer is still loading rather than guessing.
  String _subtitle(WidgetRef ref) {
    final coverage = ref.watch(homeCoverageProvider).valueOrNull?.data;
    if (coverage == null || !coverage.hasCoverage) {
      return 'Real timetables from the operators themselves.';
    }

    final modes = coverage.modesSentence;
    return modes.isEmpty
        ? 'Transit across ${coverage.region}.'
        : '$modes across ${coverage.region}.';
  }

  /// "Good morning" / "Good afternoon" / "Good evening", from the device
  /// clock. Cheap personality: it costs nothing and tells the rider the screen
  /// knows what time they are travelling at.
  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final area = ref.watch(homeAreaProvider);
    final drift = ref.watch(locationDriftProvider);
    // Null until sign-in, and null for a signed-in account with no name set.
    // Either way the greeting simply stops early rather than guessing.
    final name = ref.watch(currentUserProvider).valueOrNull?.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // The mark on transparency, so it sits on the page rather than in
            // a white tile of its own.
            Image.asset(
              'assets/brand/ratroo_logo.png',
              height: 28,
              semanticLabel: 'Ratroo',
            ),
            const Spacer(),
            Text(
              name == null
                  ? greeting(DateTime.now())
                  : '${greeting(DateTime.now())}, $name',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),
        const SizedBox(height: RatrooTheme.space6),
        Text(
          'Where would you\nlike to go today?',
          style: GoogleFonts.outfit(
            fontSize: 34,
            height: 1.15,
            fontWeight: FontWeight.bold,
            letterSpacing: -0.5,
            color: theme.colorScheme.onSurface,
          ),
        ).animate().fadeIn(delay: 60.ms).slideY(begin: -0.15, end: 0),
        const SizedBox(height: RatrooTheme.space3),
        Text(
          // Was "Live bus, metro, rail and ferry across West Bengal" for
          // everyone — wrong in Karnataka, and wrong about metro everywhere,
          // since no metro routes are mapped at all.
          _subtitle(ref),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ).animate().fadeIn(delay: 120.ms).slideY(begin: -0.15, end: 0),
        if (area != null) ...[
          const SizedBox(height: RatrooTheme.space4),
          _LocationPill(area: area),
        ],
        if (drift != null) ...[
          const SizedBox(height: RatrooTheme.space4),
          _MovedBanner(to: drift),
        ],
      ],
    );
  }

  /// Four ways in, as one grouped control rather than four coloured tiles.
  ///
  /// The previous version gave each action its own saturated colour — blue,
  /// teal, purple, pink. Two things were wrong with that. Colour in this app
  /// means *mode*: blue is bus, purple is rail, cyan is ferry. Spending those
  /// colours on actions that are not modes breaks the one visual system a
  /// rider learns. And four equally loud tiles have no hierarchy, which is the
  /// look of a generated dashboard rather than a designed screen.
  ///
  /// So: one surface, monochrome glyphs, and exactly one action carrying the
  /// brand colour — planning a trip is what this app is for.
  Widget _buildQuickAccess(BuildContext context) {
    final theme = Theme.of(context);

    const items = [
      (AppIcons.planSolid, 'Plan', '/journey-planner', true),
      (AppIcons.nearMeSolid, 'Nearby', '/nearby', false),
      (AppIcons.exploreSolid, 'Explore', '/providers', false),
      (AppIcons.assistantSolid, 'Assistant', '/assistant', false),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: RatrooTheme.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: _QuickAccessTile(
                icon: item.$1,
                label: item.$2,
                route: item.$3,
                primary: item.$4,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0);
  }

  /// The main way in. Sized and weighted as the primary action rather than a
  /// grey pill: it is what the headline just asked the rider to do.
  ///
  /// Opens stop search, not the assistant. Tapping "Search anywhere" and
  /// landing in a chat was the wrong promise; the assistant has its own entry
  /// in the row below.
  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);

    return TiltTap(
      onTap: () => context.push('/search'),
      borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space4,
          vertical: RatrooTheme.space3,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(AppIcons.search, color: Colors.white, size: 20),
            ),
            const SizedBox(width: RatrooTheme.space3),
            Expanded(
              child: Text(
                'Search any stop or station',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.96, 0.96));
  }

  Widget _buildNearbySection(BuildContext context, WidgetRef ref) {
    final nearbyAsync = ref.watch(homeNearbyStationsProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Ready to travel?', style: theme.textTheme.headlineSmall),
            TextButton(
              onPressed: () => context.push('/nearby'),
              child: Text(
                'See Map',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        nearbyAsync.when(
          data: (response) {
            final result = response.data;
            final stops = result?.places ?? const <Place>[];
            if (stops.isEmpty) {
              // Says how far it looked, so "none" reads as a fact about the
              // area rather than a broken screen.
              return _buildEmptyState(
                context,
                icon: AppIcons.locationOff,
                message:
                    'No stops within ${result?.radiusLabel ?? "30 km"} of you.',
              );
            }
            // Only the modes that actually run here. This row was a fixed
            // Bus/Ferry/Train/Metro — in Karnataka three of the four opened an
            // empty list, and Metro opened one everywhere, since no metro
            // route or stop has ever been ingested.
            final coverage = ref.watch(homeCoverageProvider).valueOrNull?.data;
            final modes = coverage?.modes ?? const [];
            final chips = _modeChips.entries
                .where((e) => modes.contains(e.key))
                .toList();

            if (chips.isEmpty) {
              return Text(
                'No services mapped around you yet.',
                style: theme.textTheme.bodyMedium,
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result != null && result.widened) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
                    child: Text(
                      'Nothing within 1 km — showing services within '
                      '${result.radiusLabel}.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
                _modeRow(context, chips, coverage),
              ],
            );
          },
          loading: () => Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(4, (index) => _buildShimmerCircle(context)),
          ),
          error: (err, stack) => _buildErrorState(context, err.toString()),
        ),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  /// The mode circles themselves, split out so the widened-search note can sit
  /// above them without nesting the whole row another level deep.
  Widget _modeRow(
    BuildContext context,
    List<MapEntry<String, (IconData, String)>> chips,
    CoverageSummary? coverage,
  ) {
    return Row(
      mainAxisAlignment: chips.length < 3
          ? MainAxisAlignment.start
          : MainAxisAlignment.spaceBetween,
      children: [
        for (final chip in chips)
          _buildTransitMode(
            context,
            chip.value.$1,
            chip.value.$2,
            chip.key,
            counts: coverage?.mode(chip.key),
          ),
      ],
    );
  }

  /// The tinted circle used before photos, kept for modes without one.
  Widget _modeGlyph(ThemeData theme, IconData icon) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.primary.withValues(alpha: 0.1),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, color: theme.colorScheme.primary, size: 28),
  );

  Widget _buildTransitMode(
    BuildContext context,
    IconData icon,
    String label,
    String mode, {
    ModeCoverage? counts,
  }) {
    final theme = Theme.of(context);

    // These were decoration — no tap handler at all. Each now opens Nearby
    // filtered to that mode.
    return InkWell(
      onTap: () => context.push('/nearby?mode=${mode.toUpperCase()}'),
      borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            if (_modePhotos.contains(mode))
              // A photograph of the actual vehicle reads faster than a glyph,
              // and a Kolkata tram looks nothing like a generic tram icon.
              ClipOval(
                child: Image.asset(
                  'assets/brand/mode_$mode.jpg',
                  width: 62,
                  height: 62,
                  fit: BoxFit.cover,
                  semanticLabel: label,
                  // A missing or corrupt asset must not take the row down.
                  errorBuilder: (_, _, _) => _modeGlyph(theme, icon),
                ),
              )
            else
              _modeGlyph(theme, icon),
            const SizedBox(height: 8),
            Text(label, style: theme.textTheme.labelLarge),
            // The count lives with the mode it describes rather than in a
            // second list further down the page — the modes were being drawn
            // twice, once as photographs and once as rows.
            if (counts != null && counts.routeCount > 0)
              Text(
                '${groupedNumber(counts.routeCount)} routes',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: RatrooTheme.modeColor(mode),
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerCircle(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1200.ms,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
        const SizedBox(height: 8),
        Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
            )
            .animate(onPlay: (controller) => controller.repeat())
            .shimmer(
              duration: 1200.ms,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
            ),
      ],
    );
  }

  /// Real coverage, not a status light.
  ///
  /// This section used to read "System Status: Normal Operations — 95%
  /// Reliable". Both values were defaults for an endpoint that returns 501, so
  /// the figure never changed and measured nothing. A route count is a fact we
  /// actually hold.
  /// The network, mode by mode, with the counts we actually hold.
  ///
  /// Was a single "N routes" line. A rider cannot tell from one number whether
  /// their ferry is covered, and the old card implied the whole network was
  /// equally mapped when metro has nothing in it at all.
  Widget _buildNetworkSection(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(homeCoverageProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        countAsync.when(
          data: (response) {
            final coverage = response.data;
            if (coverage == null || !coverage.hasCoverage) {
              return GlassContainer(
                padding: const EdgeInsets.all(20),
                child: Text(
                  // Distinguishes "we have nothing here" from "the request
                  // failed" — both used to read as a loading error.
                  coverage == null
                      ? 'Could not load coverage right now.'
                      : 'No routes are mapped around you yet.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // The region names itself: "West Bengal network" in Kolkata,
                  // "Karnataka network" in Bengaluru.
                  '${coverage.region} network',
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: RatrooTheme.space1),
                Text(
                  // The stop count is only claimed when we have one. An older
                  // API build sends no count, and "across 0 stops" reads as an
                  // empty network rather than a missing field.
                  coverage.stopCount > 0
                      ? '${groupedNumber(coverage.routeCount)} routes across '
                            '${groupedNumber(coverage.stopCount)} stops. '
                            'Not every route has a published timetable yet.'
                      : '${groupedNumber(coverage.routeCount)} routes. '
                            'Not every route has a published timetable yet.',
                  style: theme.textTheme.bodyMedium,
                ),
                if (coverage.lastUpdated != null) ...[
                  const SizedBox(height: RatrooTheme.space2),
                  Row(
                    children: [
                      Icon(
                        AppIcons.time,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.45,
                        ),
                      ),
                      const SizedBox(width: RatrooTheme.space2),
                      Text(
                        'Updated ${timeAgo(coverage.lastUpdated!)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ],
            );
          },
          loading: () =>
              Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(
                    duration: 1200.ms,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  ),
          error: (err, stack) => _buildErrorState(context, err.toString()),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildSavedRoutes(BuildContext context, WidgetRef ref) {
    final routesAsync = ref.watch(homeSavedRoutesProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your journeys', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 16),
        routesAsync.when(
          data: (response) {
            final routes = response.data ?? [];
            if (routes.isEmpty) {
              return _buildEmptyState(
                context,
                icon: AppIcons.bookmark,
                message: 'No saved routes yet.',
              );
            }
            return Column(
              children: routes.take(3).map<Widget>((route) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => context.push('/route-details?id=${route.id}'),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.03,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.08,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              AppIcons.route,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${route.originName} → ${route.destinationName}',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  route.routeCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            AppIcons.chevron,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => Column(
            children: List.generate(
              2,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child:
                    Container(
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        )
                        .animate(onPlay: (controller) => controller.repeat())
                        .shimmer(
                          duration: 1200.ms,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                        ),
              ),
            ),
          ),
          error: (err, stack) => _buildErrorState(context, err.toString()),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: GoogleFonts.inter(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(AppIcons.error, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error loading data. Pull to refresh.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RatrooTheme.space4,
        0,
        RatrooTheme.space4,
        RatrooTheme.space4,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: _navigationBar(context, theme),
        ),
      ),
    );
  }

  Widget _navigationBar(BuildContext context, ThemeData theme) {
    return NavigationBar(
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      height: 68,
      indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.1),
      selectedIndex: 2,
      onDestinationSelected: (index) {
        // Was a hardcoded route uuid that 404s once that row is reprojected.
        if (index == 0) context.push('/journey-planner');
        // Search opened the Journey Planner, so there was no way to look up a
        // single stop by name. It now opens stop search.
        if (index == 1) context.push('/search');
        if (index == 3) context.push('/nearby');
        if (index == 4) context.push('/profile');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(AppIcons.alternatives),
          selectedIcon: Icon(AppIcons.alternativesSelected),
          label: 'Plan',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.search),
          selectedIcon: Icon(AppIcons.searchSelected),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.home),
          selectedIcon: Icon(AppIcons.homeSelected),
          label: 'Home',
        ),
        // Was a bookmark, which is a different promise: this tab shows what is
        // around the rider now, not what they saved.
        NavigationDestination(
          icon: Icon(AppIcons.nearMe),
          selectedIcon: Icon(AppIcons.nearMeSelected),
          label: 'Nearby',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.user),
          selectedIcon: Icon(AppIcons.userSelected),
          label: 'Profile',
        ),
      ],
    );
  }
}

/// One Quick Access square: icon over a two-line label, whole tile tappable.
class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  /// The one action the screen is really for. Exactly one of these is true.
  final bool primary;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint = primary
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.72);

    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
      child: Padding(
        // Vertical padding keeps each target past the 48dp minimum without a
        // border drawing a box around it.
        padding: const EdgeInsets.symmetric(vertical: RatrooTheme.space2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: tint),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              label,
              maxLines: 1,
              style: theme.textTheme.labelLarge?.copyWith(
                color: primary
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
                fontWeight: primary ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
