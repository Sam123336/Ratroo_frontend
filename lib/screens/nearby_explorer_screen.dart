import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/location_service.dart';
import '../models/place.dart';
import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/transit_icons.dart';
import '../providers/api_providers.dart';
import '../services/nearby_service.dart';
import '../widgets/glass_container.dart';

// Uses the device's real position. This was hardcoded to Kolkata centre, so a
// user in Bardhaman was shown stops 100km away labelled "Nearby".
final nearbyPlacesProvider =
    FutureProvider.autoDispose.family<ApiResponse<NearbyResult>, String?>((ref, mode) async {
  final location = await ref.watch(userLocationProvider.future);
  final service = ref.watch(nearbyServiceProvider);

  // Bus stops are everywhere; a ferry ghat is not, and in rural districts the
  // nearest stop of any kind can be 10 km away. Unfiltered searches widen
  // until they find something; a mode filter goes straight to the wide radius
  // because there are only ~20 ghats in the whole state.
  if (mode != null) {
    final response = await service.getNearbyStops(
        location.latitude, location.longitude, radius: 25000);
    return ApiResponse(
      success: response.success,
      error: response.error,
      data: NearbyResult(places: response.data ?? const [], radiusMetres: 25000),
    );
  }

  return service.findNearest(location.latitude, location.longitude);
});

/// Up to three services, then a count of the rest. Capped because a Kolkata
/// interchange serves dozens and the row has to stay a row.
class _RouteBadges extends StatelessWidget {
  final List<PlaceRoute> routes;

  /// The stop these routes call at, so a badge names the far end of the trip.
  final String stopName;

  const _RouteBadges({required this.routes, required this.stopName});

  static const _visible = 3;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shown = routes.take(_visible).toList();
    final hidden = routes.length - shown.length;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final route in shown)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                route.shortLabelAt(stopName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        if (hidden > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              '+$hidden more',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
      ],
    );
  }
}

class NearbyExplorerScreen extends ConsumerStatefulWidget {
  /// Optional mode filter from the home screen's Bus/Ferry/Train/Metro buttons.
  final String? mode;

  const NearbyExplorerScreen({super.key, this.mode});

  @override
  ConsumerState<NearbyExplorerScreen> createState() => _NearbyExplorerScreenState();
}

class _NearbyExplorerScreenState extends ConsumerState<NearbyExplorerScreen> {
  bool _isMapMode = false;
  final MapController _mapController = MapController();

  /// Pinch-zoom works, but there were no on-screen controls at all.
  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(camera.center, (camera.zoom + delta).clamp(3.0, 19.0));
  }

  String _modeLabel(String mode) =>
      mode[0].toUpperCase() + mode.substring(1).toLowerCase();

  /// Stop categories look like BUS_STOP / METRO_STATION / FERRY_TERMINAL.
  List<Place> _applyModeFilter(List<Place> places) {
    final mode = widget.mode;
    if (mode == null) return places;

    final needle = mode.toUpperCase();
    // No fallback to the unfiltered list: doing that showed bus stops under
    // "Nearby Ferry", which is worse than an honest empty state.
    return places.where((p) => (p.type ?? '').toUpperCase().contains(needle)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final nearbyPlacesAsync = ref.watch(nearbyPlacesProvider(widget.mode));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == null ? 'Nearby Explorer' : 'Nearby ${_modeLabel(widget.mode!)}'),
        actions: [
          IconButton(
            icon: Icon(_isMapMode ? Icons.list : Icons.map),
            onPressed: () {
              setState(() {
                _isMapMode = !_isMapMode;
              });
            },
          ),
        ],
      ),
      body: nearbyPlacesAsync.when(
        data: (apiResponse) {
          final result = apiResponse.data;
          final places = _applyModeFilter(result?.places ?? const []);
          final body = places.isEmpty
              ? _buildEmptyState(result)
              : _isMapMode
                  ? _buildMapMode(places)
                  : _buildListMode(places);

          // Tell the user when these are not actually near them.
          final location = ref.watch(userLocationProvider).valueOrNull;
          if (location == null || location.isLive) return body;

          return Column(children: [_buildLocationBanner(location), Expanded(child: body)]);
        },
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  /// Shown when stops are relative to the Kolkata fallback, not the user.
  Widget _buildLocationBanner(UserLocation location) {
    final theme = Theme.of(context);
    final blocked = location.status == LocationStatus.deniedForever;

    return Container(
      width: double.infinity,
      color: RatrooTheme.confidenceMedFill.withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.location_off, size: 18, color: RatrooTheme.confidenceMedText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              locationStatusMessage(location.status),
              style: theme.textTheme.bodySmall?.copyWith(color: RatrooTheme.confidenceMedText),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (blocked) {
                await ref.read(locationServiceProvider).openSettings();
              }
              // Forced, so the retry asks the OS again rather than being
              // answered from the two-minute cache.
              await ref.read(locationServiceProvider).current(forceRefresh: true);
              ref.invalidate(userLocationProvider);
              ref.invalidate(nearbyPlacesProvider(widget.mode));
            },
            child: Text(blocked ? 'Settings' : 'Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildListMode(List<Place> places) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: places.length,
      itemBuilder: (context, index) {
        final place = places[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => context.push('/place-details?id=${place.id}'),
            borderRadius: BorderRadius.circular(16),
            child: GlassContainer(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    ModeAvatar(category: place.type),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            place.canonicalName,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            place.readableType,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          // Which services you can actually catch here. The row
                          // used to give only a name and a distance, which does
                          // not tell you whether the stop is any use to you.
                          if (place.routes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            _RouteBadges(routes: place.routes, stopName: place.canonicalName),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Was a ConfidenceGauge showing the same API-wide score on
                    // every row, labelled "% Reliable" — it said nothing about
                    // the stop. How far away it is, does.
                    if (place.distanceLabel != null)
                      Text(
                        place.distanceLabel!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX(begin: 0.1, end: 0),
        );
      },
    );
  }

  Widget _buildMapMode(List<Place> places) {
    if (places.isEmpty) return _buildEmptyState(null);
    
    // Default to first place location or standard center
    final center = LatLng(places.first.lat ?? 0.0, places.first.lon ?? 0.0);

    return Stack(children: [
      FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14.0,
      ),
      children: [
        // CARTO's OSM-derived basemap, not tile.openstreetmap.org. OSM's
        // volunteer tile servers forbid app traffic and returned 403
        // "Access blocked" on every tile, whatever user agent was set.
        // Swap for a keyed provider (MapTiler, Stadia) before heavy use.
        TileLayer(
          urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.ratroo_app',
          subdomains: const ['a', 'b', 'c', 'd'],
          maxNativeZoom: 20,
        ),
        // Attribution is a licence condition for OSM-derived tiles, not decoration.
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('© OpenStreetMap contributors'),
            TextSourceAttribution('© CARTO'),
          ],
        ),
        MarkerLayer(
          markers: places.map((place) {
            return Marker(
              point: LatLng(place.lat ?? 0.0, place.lon ?? 0.0),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () => context.push('/place-details?id=${place.id}'),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.directions_bus, color: Colors.white, size: 24),
                ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack),
              ),
            );
          }).toList(),
        ),
      ],
      ).animate().fadeIn(),
      Positioned(
        right: 16,
        bottom: 96,
        child: Column(
          children: [
            _ZoomButton(icon: Icons.add, tooltip: 'Zoom in', onTap: () => _zoomBy(1)),
            const SizedBox(height: 8),
            _ZoomButton(icon: Icons.remove, tooltip: 'Zoom out', onTap: () => _zoomBy(-1)),
          ],
        ),
      ),
    ]);
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassContainer(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 16,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
         .shimmer(duration: 1200.ms, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05));
      },
    );
  }

  Widget _buildEmptyState([NearbyResult? result]) {
    // How far the search actually reached, so "nothing here" reads as a fact
    // about the area rather than a broken screen.
    final radius = result?.radiusLabel ?? '30 km';
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 16),
          Text(
            widget.mode == null
                ? 'No stops within $radius'
                : 'No ${_modeLabel(widget.mode!).toLowerCase()} stops within $radius',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 8),
          Text(
            widget.mode == null
                ? 'Ratroo looked out to $radius and found nothing mapped here yet.'
                // Only bus data has been ingested into the stops table so far.
                : 'Only bus stops have been imported so far. Ferry, rail and metro coverage is still being ingested.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ).animate().shake(duration: 400.ms),
            const SizedBox(height: 16),
            Text(
              'Oops! Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fadeIn(delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ).animate().fadeIn(delay: 400.ms),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                ref.invalidate(nearbyPlacesProvider(widget.mode));
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ).animate().scale(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}

/// Circular map control. Matches the FAB look already used elsewhere.
class _ZoomButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ZoomButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        onPressed: onTap,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}
