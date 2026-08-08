import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/api_providers.dart';
import '../models/coverage_summary.dart';
import '../models/place.dart';
import '../models/route.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../widgets/glass_container.dart';

// Stops around wherever the user actually is.
final homeNearbyStationsProvider = FutureProvider.autoDispose<ApiResponse<List<Place>>>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  return ref.watch(nearbyServiceProvider).getNearbyStops(location.latitude, location.longitude);
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

  final places = ref.watch(homeNearbyStationsProvider).valueOrNull?.data ?? const <Place>[];
  for (final place in places) {
    final area = place.areaName;
    if (area != null) return area;
  }
  return null;
});

// Fetch saved routes/favorites
final homeSavedRoutesProvider = FutureProvider.autoDispose<ApiResponse<List<RouteModel>>>((ref) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getFavorites();
});

/// Label per route type the API can report. "rail" is shown as "Train"
/// because that is what people call it; the key stays the API's word.
///
/// Modes with a photo in assets/brand show it; the rest fall back to an icon.
/// Metro has no photo because it has no data either — it never renders.
const _modeChips = <String, (IconData, String)>{
  'bus': (Icons.directions_bus, 'Bus'),
  'rail': (Icons.train, 'Train'),
  'ferry': (Icons.directions_boat, 'Ferry'),
  'tram': (Icons.tram, 'Tram'),
  'metro': (Icons.subway, 'Metro'),
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
          const Icon(Icons.my_location, size: 20, color: RatrooTheme.confidenceMedText),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'You have moved since this loaded.',
              style: theme.textTheme.bodyMedium?.copyWith(color: RatrooTheme.confidenceMedText),
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            // Location first: pulling to refresh re-read the stops but kept the
            // old position, so a user who had travelled saw the same city
            // however many times they pulled.
            ref.read(locationDriftProvider.notifier).state = null;
            // Forced: the service holds a fix for two minutes, and a deliberate
            // pull should not be answered from that cache.
            await ref.read(locationServiceProvider).current(forceRefresh: true);
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
              const SizedBox(height: 28),
              _buildQuickAccess(context),
              const SizedBox(height: 32),
              _buildNearbySection(context, ref),
              const SizedBox(height: 32),
              _buildTransitReliability(context, ref),
              const SizedBox(height: 32),
              _buildSavedRoutes(context, ref),
            ],
          ),
        ),
      ),
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

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final area = ref.watch(homeAreaProvider);
    final drift = ref.watch(locationDriftProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The mark on transparency, so it sits on the page rather than in a
        // white tile of its own.
        Image.asset(
          'assets/brand/ratroo_logo.png',
          height: 34,
          semanticLabel: 'Ratroo',
        ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
        const SizedBox(height: 12),
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            children: [
              const TextSpan(text: 'Where to'),
              // No city rather than the wrong city when we cannot name one.
              if (area == null)
                const TextSpan(text: '?')
              else ...[
                const TextSpan(text: ', '),
                TextSpan(
                  text: '$area?',
                  style: const TextStyle(color: RatrooTheme.primaryColor),
                ),
              ],
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          // Was "Live bus, metro, rail and ferry across West Bengal" for
          // everyone — wrong in Karnataka, and wrong about metro everywhere,
          // since no metro routes are mapped at all.
          _subtitle(ref),
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),
        if (drift != null) ...[
          const SizedBox(height: 16),
          _MovedBanner(to: drift),
        ],
      ],
    );
  }

  /// Four ways into the app that are otherwise buried. Every destination here
  /// is a screen backed by real data — no placeholders for features that do
  /// not exist yet.
  Widget _buildQuickAccess(BuildContext context) {
    const items = [
      (Icons.near_me_outlined, 'Nearby\nStops', '/nearby'),
      (Icons.alt_route_outlined, 'Plan a\nJourney', '/journey-planner'),
      (Icons.business_outlined, 'Operators', '/providers'),
      (Icons.auto_awesome_outlined, 'Ask\nRatroo', '/assistant'),
    ];

    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _QuickAccessTile(icon: item.$1, label: item.$2, route: item.$3),
            ),
          ),
      ],
    ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/assistant'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ask anything — "Sealdah theke Bongaon"',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
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
            Text(
              'Nearby Stations',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
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
            final stops = response.data ?? [];
            if (stops.isEmpty) {
              return _buildEmptyState(
                context,
                icon: Icons.location_off,
                message: 'No nearby stations found.',
              );
            }
            // Only the modes that actually run here. This row was a fixed
            // Bus/Ferry/Train/Metro — in Karnataka three of the four opened an
            // empty list, and Metro opened one everywhere, since no metro
            // route or stop has ever been ingested.
            final modes = ref.watch(homeCoverageProvider).valueOrNull?.data?.modes ?? const [];
            final chips = _modeChips.entries.where((e) => modes.contains(e.key)).toList();

            if (chips.isEmpty) {
              return Text(
                'No services mapped around you yet.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              );
            }

            return Row(
              mainAxisAlignment: chips.length < 3
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.spaceBetween,
              children: [
                for (final chip in chips)
                  _buildTransitMode(context, chip.value.$1, chip.value.$2, chip.key),
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

  /// The tinted circle used before photos, kept for modes without one.
  Widget _modeGlyph(ThemeData theme, IconData icon) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.primary, size: 28),
      );

  Widget _buildTransitMode(BuildContext context, IconData icon, String label, String mode) {
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
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
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
            .shimmer(duration: 1200.ms, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
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
            .shimmer(duration: 1200.ms, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
      ],
    );
  }

  /// Real coverage, not a status light.
  ///
  /// This section used to read "System Status: Normal Operations — 95%
  /// Reliable". Both values were defaults for an endpoint that returns 501, so
  /// the figure never changed and measured nothing. A route count is a fact we
  /// actually hold.
  Widget _buildTransitReliability(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(homeCoverageProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coverage',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
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
                  style: GoogleFonts.inter(fontSize: 14, color: theme.colorScheme.onSurface),
                ),
              );
            }

            return GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, color: theme.colorScheme.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${coverage.routeCount} routes in ${coverage.region}',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${coverage.modesSentence}. '
                          'Not every route has a published timetable yet.',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => Container(
            height: 100,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
          )
              .animate(onPlay: (controller) => controller.repeat())
              .shimmer(duration: 1200.ms, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
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
        Text(
          'Saved Routes',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        routesAsync.when(
          data: (response) {
            final routes = response.data ?? [];
            if (routes.isEmpty) {
              return _buildEmptyState(
                context,
                icon: Icons.bookmark_border,
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
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.route, color: theme.colorScheme.primary),
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
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
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
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .shimmer(duration: 1200.ms, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
              ),
            ),
          ),
          error: (err, stack) => _buildErrorState(context, err.toString()),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildEmptyState(BuildContext context, {required IconData icon, required String message}) {
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
          Icon(icon, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
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
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Error loading data. Pull to refresh.',
              style: GoogleFonts.inter(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationBar(
      elevation: 0,
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
          icon: Icon(Icons.alt_route_outlined),
          selectedIcon: Icon(Icons.alt_route),
          label: 'Plan',
        ),
        NavigationDestination(
          icon: Icon(Icons.search_outlined),
          selectedIcon: Icon(Icons.search),
          label: 'Search',
        ),
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.bookmark_outline),
          selectedIcon: Icon(Icons.bookmark),
          label: 'Nearby',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
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

  const _QuickAccessTile({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
      child: Container(
        // 88 high keeps the whole square well past the 48dp touch minimum.
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
          border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: theme.colorScheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                letterSpacing: 0,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
