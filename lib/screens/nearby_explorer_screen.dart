import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/place.dart';
import '../core/api_client.dart';
import '../providers/api_providers.dart';
import '../widgets/glass_container.dart';
import '../widgets/confidence_gauge.dart';

final nearbyPlacesProvider = FutureProvider.autoDispose<ApiResponse<List<Place>>>((ref) async {
  final nearbyService = ref.watch(nearbyServiceProvider);
  return nearbyService.getNearbyStops(22.5726, 88.3639);
});

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
    final nearbyPlacesAsync = ref.watch(nearbyPlacesProvider);

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
          final places = _applyModeFilter(apiResponse.data ?? []);
          if (places.isEmpty) {
            return _buildEmptyState();
          }
          return _isMapMode ? _buildMapMode(places) : _buildListMode(places, apiResponse.metadata?.confidenceScore ?? 0.0);
        },
        loading: () => _buildLoadingState(),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildListMode(List<Place> places, double confidenceScore) {
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
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.directions_bus,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
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
                            place.type ?? 'Bus Stop',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ConfidenceGauge(score: confidenceScore),
                        const SizedBox(height: 4),
                        Text(
                          'Nearby',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
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
    if (places.isEmpty) return _buildEmptyState();
    
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

  Widget _buildEmptyState() {
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
                ? 'No places found nearby'
                : 'No ${_modeLabel(widget.mode!).toLowerCase()} stops nearby',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 8),
          Text(
            widget.mode == null
                ? 'Try adjusting your location or check back later.'
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
                ref.invalidate(nearbyPlacesProvider);
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
