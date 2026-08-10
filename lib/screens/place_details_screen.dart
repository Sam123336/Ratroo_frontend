import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/api_providers.dart';
import '../models/place.dart';
import '../core/location_service.dart';
import '../core/transit_icons.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../core/app_icons.dart';
import '../widgets/status_view.dart';
import '../widgets/skeleton.dart';

// Fetch by id. This used to call searchPlaces(id) — searching for a UUID by
// name — so the screen could only ever render "No details found".
final placeDetailsProvider =
    FutureProvider.autoDispose.family<ApiResponse<Place>, String>((ref, id) async {
  final service = ref.watch(searchServiceProvider);
  return service.getPlaceById(id);
});

/// What is at this stop and when the next services leave.
///
/// This screen used to lead with a "Connectivity Index" and a "Reliability"
/// percentage that was a hardcoded string. Both are gone: a rider needs
/// departures, destinations and routes, not the database's opinion of itself.
class PlaceDetailsScreen extends ConsumerWidget {
  final String? placeId;

  const PlaceDetailsScreen({super.key, this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (placeId == null || placeId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Stop')),
        body: const StatusView(
          kind: StatusKind.noLocation,
          message: 'No stop was selected.',
          detail: 'Open a stop from search or the nearby list.',
        ),
      );
    }

    final async = ref.watch(placeDetailsProvider(placeId!));
    final title = async.valueOrNull?.data?.canonicalName ?? 'Stop';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(placeDetailsProvider(placeId!)),
        child: async.when(
          data: (response) {
            final place = response.data;
            if (place == null) {
              return StatusView(
                kind: StatusKind.empty,
                message: 'We have no details for this stop yet.',
                detail: response.error,
              );
            }
            return _PlaceBody(place: place);
          },
          loading: () => const SkeletonList(count: 6),
          error: (err, _) => StatusView.fromError(
            err,
            message: 'Could not load this stop.',
            onRetry: () => ref.invalidate(placeDetailsProvider(placeId!)),
          ),
        ),
      ),
    );
  }
}

class _PlaceBody extends ConsumerWidget {
  final Place place;

  const _PlaceBody({required this.place});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = ref.watch(nowProvider)();
    final nowMinutes = now.hour * 60 + now.minute;

    // Departures already sorted by the API. Split at "now" so the next service
    // is at the top, with earlier ones still reachable below.
    final upcoming = place.departures
        .where((d) => (d.minutesOfDay ?? -1) >= nowMinutes)
        .toList();
    final earlier = place.departures
        .where((d) => (d.minutesOfDay ?? 1 << 30) < nowMinutes)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          RatrooTheme.space4, RatrooTheme.space4, RatrooTheme.space4, RatrooTheme.space8),
      children: [
        _header(context, ref, theme),
        const SizedBox(height: RatrooTheme.space6),
        _sectionTitle(theme, 'Departures'),
        const SizedBox(height: RatrooTheme.space2),
        if (place.departures.isEmpty)
          _noTimetableNotice(theme)
        else ...[
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
              child: Text(
                'Nothing more scheduled today. Tomorrow starts at ${place.departures.first.time}.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ...upcoming.take(12).map((d) => _DepartureTile(departure: d, nowMinutes: nowMinutes)),
          if (earlier.isNotEmpty || upcoming.length > 12)
            _FullTimetableTile(place: place, nowMinutes: nowMinutes),
        ],
        const SizedBox(height: RatrooTheme.space6),
        _sectionTitle(theme, 'Routes stopping here'),
        const SizedBox(height: RatrooTheme.space2),
        if (place.routes.isEmpty)
          Text('No routes are recorded here yet.', style: theme.textTheme.bodyMedium)
        else
          ...place.routes.map((r) => _RouteTile(route: r, category: place.type)),
        const SizedBox(height: RatrooTheme.space6),
        _sources(context, theme),
      ],
    );
  }

  Widget _header(BuildContext context, WidgetRef ref, ThemeData theme) {
    final distance = ref.watch(userLocationProvider).maybeWhen(
          data: (loc) => loc.isLive ? _distanceLabel(loc) : null,
          orElse: () => null,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(place.canonicalName, style: theme.textTheme.headlineSmall),
        const SizedBox(height: RatrooTheme.space2),
        Wrap(
          spacing: RatrooTheme.space2,
          runSpacing: RatrooTheme.space2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _Chip(icon: modeIcon(place.type), label: place.readableType),
            if (distance != null) _Chip(icon: AppIcons.nearMe, label: distance),
            if (place.lat != null && place.lon != null)
              ActionChip(
                avatar: const Icon(AppIcons.map, size: 16),
                label: const Text('Open in maps'),
                onPressed: () => _openMap(context),
              ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  /// Straight-line distance — honest about being "as the crow flies", since we
  /// have no walking network to route over.
  String? _distanceLabel(UserLocation loc) {
    if (place.lat == null || place.lon == null) return null;
    final metres = distanceMetres(loc.latitude, loc.longitude, place.lat!, place.lon!);
    return metres < 1000
        ? '${metres.round()} m away'
        : '${(metres / 1000).toStringAsFixed(1)} km away';
  }

  Future<void> _openMap(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse('geo:${place.lat},${place.lon}?q=${place.lat},${place.lon}'
        '(${Uri.encodeComponent(place.canonicalName)})');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(const SnackBar(content: Text('No maps app to open this.')));
    }
  }

  Widget _noTimetableNotice(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(RatrooTheme.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
        border: Border.all(color: theme.colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.time, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: RatrooTheme.space3),
          Expanded(
            child: Text(
              'No timetable has been published for this stop yet. '
              'The routes below do stop here — we just do not have their times.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(ThemeData theme, String text) =>
      Text(text, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));

  Widget _sources(BuildContext context, ThemeData theme) {
    if (place.sources.isEmpty) return const SizedBox.shrink();

    final names = place.sources.map((s) => s.name).join(', ');
    final withSite = place.sources.where((s) => (s.website ?? '').isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data from $names.',
          style: theme.textTheme.labelMedium
              ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
        // The stop's own timetable page when the operator publishes one, so
        // the link does not dump the user on a search form. Falls back to the
        // operator's front page, and to nothing when neither is recorded.
        if (place.sourceUrl != null)
          TextButton.icon(
            onPressed: () => _openSite(context, place.sourceUrl!),
            icon: const Icon(AppIcons.externalLink, size: 16),
            label: Text('${place.canonicalName} timetable on WBBUS'),
          )
        else
          ...withSite.map((s) => TextButton.icon(
                onPressed: () => _openSite(context, s.website!),
                icon: const Icon(AppIcons.externalLink, size: 16),
                label: Text('${s.name} website'),
              )),
      ],
    );
  }

  Future<void> _openSite(BuildContext context, String url) async {
    final messenger = ScaffoldMessenger.of(context);
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      messenger.showSnackBar(SnackBar(content: Text('Could not open $url')));
    }
  }
}

class _DepartureTile extends StatelessWidget {
  final Departure departure;
  final int nowMinutes;

  const _DepartureTile({required this.departure, required this.nowMinutes});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final minutes = departure.minutesOfDay;
    final away = minutes == null ? null : minutes - nowMinutes;

    return Card(
      margin: const EdgeInsets.only(bottom: RatrooTheme.space2),
      child: ListTile(
        onTap: () => context.push('/route-details?id=${departure.routeId}'),
        // Kept to a single line each: a Column here overflowed ListTile's
        // leading slot as soon as a countdown appeared beneath the time.
        leading: SizedBox(
          width: 52,
          child: Text(departure.time,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ),
        title: Text(departure.headsign == null
            ? departure.routeName
            : 'To ${departure.headsign}'),
        // The bus's own name leads when we have it: at a West Bengal stand you
        // board "APANJAN", not "WBBus service 671". Most trips have no name
        // recorded, so the route name stays as the fallback.
        subtitle: Text(
          [
            departure.busLabel ?? departure.routeName,
            if (departure.isEstimated) 'estimated time',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: away != null && away <= 60
            ? Text(away <= 0 ? 'now' : 'in $away min',
                style: theme.textTheme.labelMedium
                    ?.copyWith(color: RatrooTheme.confidenceHighText, fontWeight: FontWeight.w600))
            : const Icon(AppIcons.chevron, size: 20),
      ),
    );
  }
}

/// Every remaining departure of the day, collapsed so it does not bury the
/// next few services.
class _FullTimetableTile extends StatelessWidget {
  final Place place;
  final int nowMinutes;

  const _FullTimetableTile({required this.place, required this.nowMinutes});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: RatrooTheme.space2),
      child: ExpansionTile(
        title: Text('Full timetable (${place.departures.length} departures)'),
        children: place.departures
            .map((d) => _DepartureTile(departure: d, nowMinutes: nowMinutes))
            .toList(),
      ),
    );
  }
}

class _RouteTile extends StatelessWidget {
  final PlaceRoute route;

  /// The stop's mode — a route calling at a tram stop is a tram.
  final String? category;

  const _RouteTile({required this.route, this.category});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: RatrooTheme.space2),
      child: ListTile(
        leading: Icon(modeIcon(category)),
        title: Text(route.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: route.providerCode.isEmpty ? null : Text(route.providerCode),
        trailing: const Icon(AppIcons.chevron, size: 20),
        onTap: () => context.push('/route-details?id=${route.id}'),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

