import 'dart:math' show log, ln2;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/api_providers.dart';
import '../models/route.dart';
import '../core/theme.dart';
import '../core/api_client.dart';

final routeDetailsProvider =
    FutureProvider.autoDispose.family<ApiResponse<RouteModel>, String>((ref, routeId) async {
  return ref.watch(transitServiceProvider).getRouteDetails(routeId);
});

/// Where a route goes, which stops it calls at, and when.
///
/// This screen used to headline "High Confidence — Real-time verified via
/// WBBUS Live API" beside "100% Reliable". There is no live API: the data is
/// scraped timetables. Both claims are gone, along with a "Reserve Seat"
/// button that only ever said reservation was not enabled.
class RouteDetailsScreen extends ConsumerWidget {
  final String? routeId;

  const RouteDetailsScreen({super.key, this.routeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeId == null || routeId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route')),
        body: const _Message(icon: Icons.wrong_location_outlined, text: 'No route was selected.'),
      );
    }

    final async = ref.watch(routeDetailsProvider(routeId!));

    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.data?.title ?? 'Route')),
      body: async.when(
        data: (response) {
          final route = response.data;
          if (route == null) {
            return _Message(
              icon: Icons.search_off,
              text: response.error ?? 'We have no details for this route.',
            );
          }
          return _RouteBody(route: route);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _Message(
          icon: Icons.wifi_off,
          text: 'Could not load this route.\n$err',
          onRetry: () => ref.invalidate(routeDetailsProvider(routeId!)),
        ),
      ),
    );
  }
}

class _RouteBody extends ConsumerWidget {
  final RouteModel route;

  const _RouteBody({required this.route});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timed = route.stops.where((s) => s.departureTime != null).length;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Only drawn when there is real geometry — the old header was an empty
        // gradient labelled "Live Route Path", which promised a map and showed
        // a rectangle.
        if (route.mappableStops.isNotEmpty) _RouteMap(stops: route.mappableStops),
        Padding(
          padding: const EdgeInsets.all(RatrooTheme.space4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(route.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: RatrooTheme.space2),
              Wrap(
                spacing: RatrooTheme.space2,
                runSpacing: RatrooTheme.space2,
                children: [
                  // The name on the bus leads when we have it: at a West
                  // Bengal stand you board "APANJAN", not a route code. Only
                  // WBBUS and BUSSATHI record one, so most routes show none.
                  if (route.busLabel != null)
                    Chip(
                      avatar: const Icon(Icons.directions_bus_filled, size: 16),
                      label: Text(route.busLabel!),
                      backgroundColor: RatrooTheme.accentColor.withValues(alpha: 0.12),
                      labelStyle: theme.textTheme.labelMedium
                          ?.copyWith(color: RatrooTheme.accentDeep),
                      visualDensity: VisualDensity.compact,
                    ),
                  Chip(
                    avatar: const Icon(Icons.business, size: 16),
                    label: Text(route.providerCode),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (route.stops.isNotEmpty)
                    Chip(
                      avatar: const Icon(Icons.pin_drop_outlined, size: 16),
                      label: Text('${route.stops.length} stops'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              if (route.destinationName == null && route.originName != null) ...[
                const SizedBox(height: RatrooTheme.space3),
                Text(
                  'The operator does not publish a destination for this service.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: RatrooTheme.space6),
              Text('Stops on this route',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: RatrooTheme.space3),
              if (route.stops.isEmpty)
                Text(
                  'The stop-by-stop sequence for this route has not been '
                  'published yet.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                _StopsTimeline(
                  stops: route.stops,
                  // A column of dashes tells the rider nothing. When no stop on
                  // the route has a time, the notice below says so once and
                  // both time columns are dropped entirely.
                  elapsed: route.hasNoTimes ? const [] : route.elapsedMinutes,
                  hideTimes: route.hasNoTimes,
                ),
              const SizedBox(height: RatrooTheme.space4),
              Text(
                timed == 0
                    ? '${route.providerCode} does not publish times for this '
                        'route, so the stop order is shown without them.'
                    : 'Scheduled times from ${route.providerCode}. Buses run to traffic, '
                        'not to the minute.',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              ),
              // Shown only when the operator's URL is recorded and confirmed.
              // The button used to be unconditional and always answered with a
              // snackbar saying no URL existed.
              if (route.bestSourceUrl != null)
                TextButton.icon(
                  onPressed: () => _openSite(context, route.bestSourceUrl!),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  // Names what will open. The deep link lands on this route's
                  // own timetable; the fallback is the operator's front page,
                  // where the user would have to search for it again.
                  // Promises only what opens: this route's page, the
                  // operator's route list, or its front door.
                  label: Text(switch (route.sourceKind) {
                    'route' => 'View this route on ${route.providerCode}',
                    // A cross-operator index, so it is not named after this
                    // route's own operator.
                    'search' => 'All buses on this route (WBBus.in)',
                    'index' => 'All ${route.providerCode} routes',
                    _ => 'Open ${route.providerCode} website',
                  }),
                ),
              const SizedBox(height: RatrooTheme.space8),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> _openSite(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(url);
  if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
  }
}

/// The route drawn over OpenStreetMap tiles, through the stops we can place.
class _RouteMap extends StatelessWidget {
  final List<RouteStop> stops;

  const _RouteMap({required this.stops});

  @override
  Widget build(BuildContext context) {
    final points = stops.map((s) => LatLng(s.lat!, s.lon!)).toList();
    final lats = points.map((p) => p.latitude);
    final lons = points.map((p) => p.longitude);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLon = lons.reduce((a, b) => a < b ? a : b);
    final maxLon = lons.reduce((a, b) => a > b ? a : b);

    // Centre and zoom are computed rather than handed to CameraFit: inside a
    // ListView the map's height is unbounded during layout, so CameraFit sized
    // the view to the whole viewport and the 220px box showed only its
    // northern slice — a Kolkata route framed over Bangladesh.
    final span = [maxLat - minLat, maxLon - minLon].reduce((a, b) => a > b ? a : b);
    final zoom = span <= 0
        ? 13.0
        : (log(360 / span) / ln2 - 1.5).clamp(5.0, 14.0).toDouble();

    return SizedBox(
      height: 220,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2),
          initialZoom: zoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.pinchZoom | InteractiveFlag.drag,
          ),
        ),
        children: [
          // CARTO's OSM-derived basemap: OSM's own tile servers forbid app
          // traffic and return 403 on every tile.
          TileLayer(
            urlTemplate: 'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.ratroo_app',
            subdomains: const ['a', 'b', 'c', 'd'],
            maxNativeZoom: 20,
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 4,
                color: Theme.of(context).colorScheme.primary,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final point in points)
                Marker(
                  point: point,
                  width: 12,
                  height: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          // Attribution is a licence condition for OSM-derived tiles.
          const RichAttributionWidget(
            attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
          ),
        ],
      ),
    );
  }
}

class _StopsTimeline extends StatelessWidget {
  final List<RouteStop> stops;

  /// Minutes from the first stop, aligned to [stops]. Null where unknown.
  final List<int?> elapsed;

  /// True when not one stop has a time, so both time columns are dropped.
  final bool hideTimes;

  const _StopsTimeline({
    required this.stops,
    required this.elapsed,
    this.hideTimes = false,
  });

  /// "Start", "10 mins", "1h 45m" — the trailing column on the board.
  static String? _elapsedLabel(int? minutes, bool isFirst) {
    if (isFirst) return 'Start';
    if (minutes == null) return null;
    if (minutes < 60) return '$minutes mins';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (var i = 0; i < stops.length; i++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dropped entirely when the operator publishes no times for
                // this route: a column of 15 dashes is noise, and the notice
                // under the list already explains why there are none.
                if (!hideTimes)
                  SizedBox(
                    width: 52,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        stops[i].departureTime ?? '—',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: stops[i].departureTime == null
                              ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                _Rail(isFirst: i == 0, isLast: i == stops.length - 1),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        left: RatrooTheme.space3, bottom: RatrooTheme.space4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(stops[i].name, style: theme.textTheme.bodyLarge),
                        ),
                        // Elapsed time from the origin, so a rider can see how
                        // far along the route a stop is without doing the
                        // clock arithmetic themselves.
                        Builder(builder: (context) {
                          final label = _elapsedLabel(
                              i < elapsed.length ? elapsed[i] : null, i == 0);
                          if (label == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: RatrooTheme.space3),
                            child: Text(label, style: theme.textTheme.labelMedium),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }
}

class _Rail extends StatelessWidget {
  final bool isFirst;
  final bool isLast;

  const _Rail({required this.isFirst, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final colour = Theme.of(context).colorScheme.primary;

    return SizedBox(
      width: 16,
      child: Column(
        children: [
          Expanded(
            flex: 0,
            child: Container(width: 2, height: 4, color: isFirst ? Colors.transparent : colour),
          ),
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: isFirst || isLast ? colour : Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: colour, width: 2),
            ),
          ),
          Expanded(
            child: Container(width: 2, color: isLast ? Colors.transparent : colour),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  const _Message({required this.icon, required this.text, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space8),
      children: [
        const SizedBox(height: RatrooTheme.space8),
        Icon(icon, size: 56, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
        const SizedBox(height: RatrooTheme.space4),
        Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyLarge),
        if (onRetry != null) ...[
          const SizedBox(height: RatrooTheme.space4),
          Center(child: FilledButton(onPressed: onRetry, child: const Text('Try again'))),
        ],
      ],
    );
  }
}
