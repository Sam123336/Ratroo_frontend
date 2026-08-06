import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/api_providers.dart';
import '../models/place.dart';
import '../models/route.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../widgets/glass_container.dart';
import '../widgets/confidence_gauge.dart';

// Fetch nearby stops using Kolkata coordinates for the Home screen
final homeNearbyStationsProvider = FutureProvider.autoDispose<ApiResponse<List<Place>>>((ref) async {
  final service = ref.watch(nearbyServiceProvider);
  return service.getNearbyStops(22.5726, 88.3639);
});

// Fetch saved routes/favorites
final homeSavedRoutesProvider = FutureProvider.autoDispose<ApiResponse<List<RouteModel>>>((ref) async {
  final service = ref.watch(favoritesServiceProvider);
  return service.getFavorites();
});

// Fetch system confidence/reliability
final homeConfidenceProvider = FutureProvider.autoDispose<ApiResponse<Map<String, dynamic>>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  return service.getPopularityMetrics();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeNearbyStationsProvider);
            ref.invalidate(homeSavedRoutesProvider);
            ref.invalidate(homeConfidenceProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildSearchBar(context),
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

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            children: const [
              TextSpan(text: 'Where to, '),
              TextSpan(
                text: 'Kolkata?',
                style: TextStyle(color: RatrooTheme.primaryColor),
              ),
            ],
          ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),
        const SizedBox(height: 8),
        Text(
          'Your reliable coverage for West Bengal transit.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2, end: 0),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/journey-planner'),
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
                'Search destination, stop, or route',
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
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTransitMode(context, Icons.directions_bus, 'Bus'),
                _buildTransitMode(context, Icons.directions_boat, 'Ferry'),
                _buildTransitMode(context, Icons.train, 'Train'),
                _buildTransitMode(context, Icons.subway, 'Metro'),
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

  Widget _buildTransitMode(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 28),
        ),
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

  Widget _buildTransitReliability(BuildContext context, WidgetRef ref) {
    final confidenceAsync = ref.watch(homeConfidenceProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Transit Reliability',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        confidenceAsync.when(
          data: (response) {
            final data = response.data ?? {};
            final score = (data['reliabilityScore'] as num?)?.toDouble() ?? 0.95;
            final description = data['statusDescription'] as String? ?? 'Normal Operations';
            
            return GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System Status',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ConfidenceGauge(
                    score: score,
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
        if (index == 0) context.push('/route-details?id=019fbd03-cfac-72fb-b48f-21bb81b73f76');
        if (index == 1) context.push('/journey-planner');
        if (index == 3) context.push('/nearby');
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.route_outlined),
          selectedIcon: Icon(Icons.route),
          label: 'Routes',
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
