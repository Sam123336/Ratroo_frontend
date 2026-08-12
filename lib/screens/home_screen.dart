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
import '../services/saved_answers_service.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../widgets/aurora_backdrop.dart';
import '../widgets/bus_banner.dart';
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
  // Only ever shown where they exist: the mode row is built from the modes the
  // region actually reports, so these stay absent until an operator registers
  // one.
  'auto': (AppIcons.auto, 'Auto'),
  'shared_auto': (AppIcons.sharedAuto, 'Shared auto'),
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
              // A forced fix can take twelve seconds. Leaving the screen in
              // that window disposes this element, and `invalidate` then
              // throws 'Cannot use "ref" after the widget was disposed'.
              if (!context.mounted) return;
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
    final user = ref.watch(currentUserProvider).valueOrNull;
    final name = user?.displayName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The greeting leads and the account sits opposite it — nobody opens a
        // transit app to be told which app it is.
        Row(
          children: [
            Expanded(
              child: Text(
                name == null
                    ? greeting(DateTime.now())
                    : '${greeting(DateTime.now())}, $name',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _AccountButton(name: name, email: user?.email),
          ],
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),
        const SizedBox(height: RatrooTheme.space4),
        // The question sits on frosted glass over the moving scene rather than
        // beside it. Dark text straight onto the animation would be illegible
        // wherever the bus or a tree passed behind it; the panel guarantees
        // contrast whatever frame is showing, and still lets the scene through.
        // The panel is positioned from the top rather than pinned to the
        // bottom. Bottom-aligned, it grew upwards with its own content and
        // swallowed most of the banner — the bus was behind the glass instead
        // of beside it. Starting it at a fixed offset means the overlap is a
        // decision, not a side effect of how long the subtitle happens to be.
        Stack(
          alignment: Alignment.topCenter,
          children: [
            const BusBanner(height: 190),
            Padding(
              padding: const EdgeInsets.only(top: 168),
              child: GlassContainer(
                blur: 18,
                opacity: 0.82,
                padding: const EdgeInsets.all(RatrooTheme.space6),
                borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Where would you\nlike to go today?',
                      style: GoogleFonts.outfit(
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: RatrooTheme.space2),
                    Text(
                      // Was "Live bus, metro, rail and ferry across West Bengal"
                      // for everyone — wrong in Karnataka, and wrong about metro
                      // everywhere, since no metro routes are mapped at all.
                      _subtitle(ref),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                    if (area != null) ...[
                      const SizedBox(height: RatrooTheme.space4),
                      _LocationPill(area: area),
                    ],
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.12, end: 0),
          ],
        ),
        if (drift != null) ...[
          const SizedBox(height: RatrooTheme.space4),
          _MovedBanner(to: drift),
        ],
      ],
    );
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
      // Frosted rather than solid, so it belongs to the glass panel above it
      // instead of looking like a separate white slab dropped on the page.
      child: GlassContainer(
        blur: 18,
        opacity: 0.86,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
        padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space4,
          vertical: RatrooTheme.space3,
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // The region names itself: "West Bengal network" in
                        // Kolkata, "Karnataka network" in Bengaluru.
                        '${coverage.region} network',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    // The operators list lost its tile when the duplicated
                    // action card went; it belongs here, beside the network it
                    // describes.
                    TextButton(
                      onPressed: () => context.push('/providers'),
                      child: const Text('Operators'),
                    ),
                  ],
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
        // Answers kept from the assistant sit above saved routes: they are the
        // more recent thing a rider chose to keep, and the reason they opened
        // this section.
        const _SavedAnswers(),
        routesAsync.when(
          data: (response) {
            final routes = response.data ?? [];
            if (routes.isEmpty) {
              // Only an empty section when there is nothing of either kind —
              // "No saved routes yet" under three saved answers reads as a bug.
              final answers =
                  ref.watch(savedAnswersProvider).valueOrNull ?? const [];
              if (answers.isNotEmpty) return const SizedBox.shrink();
              return _buildEmptyState(
                context,
                icon: AppIcons.bookmark,
                message:
                    'Nothing saved yet. Ask Ratroo a question and keep the answer.',
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
      selectedIndex: 0,
      onDestinationSelected: (index) {
        // Search is not a tab: the hero search bar on this screen is the way
        // in, and a tab repeating it was the same duplication as the action
        // card that used to sit above the fold.
        if (index == 1) context.push('/journey-planner');
        if (index == 2) context.push('/nearby');
        if (index == 3) context.push('/assistant');
        if (index == 4) context.push('/profile');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(AppIcons.home),
          selectedIcon: Icon(AppIcons.homeSelected),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.alternatives),
          selectedIcon: Icon(AppIcons.alternativesSelected),
          label: 'Plan',
        ),
        // Was a bookmark, which is a different promise: this tab shows what is
        // around the rider now, not what they saved.
        NavigationDestination(
          icon: Icon(AppIcons.nearMe),
          selectedIcon: Icon(AppIcons.nearMeSelected),
          label: 'Nearby',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.assistant),
          selectedIcon: Icon(AppIcons.assistant),
          label: 'Ask',
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

/// Assistant answers the rider kept, newest first.
class _SavedAnswers extends ConsumerWidget {
  const _SavedAnswers();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final answers =
        ref.watch(savedAnswersProvider).valueOrNull ?? const <SavedAnswer>[];
    if (answers.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final answer in answers.take(3))
          Padding(
            padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
            child: _SavedAnswerCard(answer: answer),
          ),
      ],
    );
  }
}

class _SavedAnswerCard extends ConsumerWidget {
  final SavedAnswer answer;

  const _SavedAnswerCard({required this.answer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Dismissible(
      key: ValueKey(answer.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) =>
          ref.read(savedAnswersProvider.notifier).remove(answer.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: RatrooTheme.space6),
        decoration: BoxDecoration(
          color: RatrooTheme.confidenceLowFill.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
        ),
        child: const Icon(AppIcons.close, color: RatrooTheme.confidenceLowText),
      ),
      child: Container(
        padding: const EdgeInsets.all(RatrooTheme.space4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  AppIcons.assistant,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: RatrooTheme.space2),
                Expanded(
                  child: Text(
                    answer.question.isEmpty ? 'Saved answer' : answer.question,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  timeAgo(answer.savedAt),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: RatrooTheme.space2),
            Text(
              answer.answer,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            // The provenance the live bubble showed, kept with the answer. An
            // ungrounded reply must not gain authority by being saved.
            if (answer.fromLiveData) ...[
              const SizedBox(height: RatrooTheme.space2),
              Row(
                children: [
                  const Icon(
                    AppIcons.verified,
                    size: 12,
                    color: RatrooTheme.confidenceHighText,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'From live route data',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: RatrooTheme.confidenceHighText,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The rider's account, reachable from the first line of the screen.
///
/// Shows their initial once we know it. Signed out, it shows a person glyph
/// rather than a guessed letter — an avatar reading "R" for a stranger is
/// worse than an obviously empty one.
class _AccountButton extends StatelessWidget {
  final String? name;
  final String? email;

  const _AccountButton({required this.name, required this.email});

  String? get _initial {
    for (final source in [name, email]) {
      final value = source?.trim();
      if (value != null && value.isNotEmpty) return value[0].toUpperCase();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = _initial;

    return Semantics(
      button: true,
      label: 'Your account',
      child: InkWell(
        borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
        onTap: () => context.push('/profile'),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: initial == null
                ? Icon(
                    AppIcons.user,
                    size: 19,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  )
                : Text(
                    initial,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
