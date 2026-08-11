import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/transit_icons.dart';
import '../models/place.dart';
import '../providers/api_providers.dart';
import '../widgets/skeleton.dart';
import '../core/app_icons.dart';
import '../widgets/status_view.dart';

/// Stops near the rider, offered before they type anything.
///
/// An empty search box used to show instructions. Instructions are not
/// suggestions: the most likely thing a rider wants is a stop they are
/// standing near, and we already know what those are.
final _nearbySuggestionsProvider = FutureProvider.autoDispose<List<Place>>((
  ref,
) async {
  final location = await ref.watch(userLocationProvider.future);
  if (!location.isLive) {
    return const [];
  }

  final response = await ref
      .watch(nearbyServiceProvider)
      .findNearest(location.latitude, location.longitude);
  // Three rows reading "Kolkata" are three separate imports of one stop.
  return mergeSamePlace(response.data?.places ?? const []);
});

final _searchResultsProvider = FutureProvider.autoDispose
    .family<ApiResponse<List<Place>>, String>((ref, query) async {
      if (query.trim().length < 2) {
        return ApiResponse(success: true, data: const []);
      }
      return ref.watch(searchServiceProvider).searchPlaces(query.trim());
    });

/// Find a stop by name.
///
/// The Search tab used to open the Journey Planner, so there was no way to look
/// up a single stop — Bankura's 800-odd departures were unreachable unless you
/// happened to be standing there.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    // The keyboard should already be up: arriving here means you want to type.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Waits for a pause in typing rather than firing per keystroke — otherwise
  /// "bankura" is seven requests and the results flicker between them.
  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              RatrooTheme.space4,
              0,
              RatrooTheme.space4,
              RatrooTheme.space3,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Stop, station or ghat',
                prefixIcon: const Icon(AppIcons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(AppIcons.close),
                        tooltip: 'Clear',
                        onPressed: () {
                          _controller.clear();
                          _onChanged('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Expanded(child: _results(theme)),
        ],
      ),
    );
  }

  Widget _results(ThemeData theme) {
    if (_query.trim().length < 2) return _intro(theme);

    return ref
        .watch(_searchResultsProvider(_query))
        .when(
          data: (response) {
            final places = response.data ?? const <Place>[];
            if (places.isEmpty) {
              return StatusView(
                kind: StatusKind.noResults,
                message: 'Nothing matches "${_query.trim()}".',
                detail:
                    'Try the stop name as it is written on the bus, '
                    'or a nearby landmark.',
              );
            }

            return ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: places.length,
              separatorBuilder: (_, _) => const SizedBox.shrink(),
              itemBuilder: (context, index) =>
                  _ResultTile(place: places[index]),
            );
          },
          loading: () => const SkeletonList(count: 6),
          error: (err, _) => StatusView.fromError(
            err,
            message: 'Search failed.',
            onRetry: () => setState(() {}),
          ),
        );
  }

  /// What to show before the query is long enough to search.
  ///
  /// Nearby stops when we know where the rider is, instructions when we do
  /// not. Two letters is still the search threshold — a single letter across
  /// 11,788 stops returns noise — but the wait is now filled with something
  /// tappable instead of a sentence telling them to keep typing.
  Widget _intro(ThemeData theme) {
    final suggestions = ref.watch(_nearbySuggestionsProvider);

    return suggestions.when(
      data: (places) {
        if (places.isEmpty) return _introMessage(theme);

        return ListView.separated(
          padding: const EdgeInsets.only(bottom: RatrooTheme.space6),
          itemCount: places.length + 1,
          // No rule between rows: the glyph column already separates them,
          // and a line under every row turns a list into a spreadsheet.
          separatorBuilder: (_, _) => const SizedBox.shrink(),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  RatrooTheme.space6,
                  RatrooTheme.space4,
                  RatrooTheme.space6,
                  RatrooTheme.space2,
                ),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.myLocation,
                      size: 15,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: RatrooTheme.space2),
                    Text('Stops near you', style: theme.textTheme.labelSmall),
                  ],
                ),
              );
            }
            return _ResultTile(place: places[index - 1]);
          },
        );
      },
      // Location can take a few seconds; skeleton rows beat a blank page.
      loading: () => const SkeletonList(count: 5),
      // No location is not an error worth a red screen here — the rider can
      // still type. Fall back to the instructions.
      error: (_, _) => _introMessage(theme),
    );
  }

  Widget _introMessage(ThemeData theme) {
    final area = ref.watch(userLocationProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      children: [
        const SizedBox(height: RatrooTheme.space8),
        Icon(
          AppIcons.explore,
          size: 48,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.25),
        ),
        const SizedBox(height: RatrooTheme.space4),
        Text(
          'Search any stop in the network',
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RatrooTheme.space2),
        Text(
          area != null && area.isLive
              ? 'Type at least two letters. Results are not limited to your area.'
              : 'Type at least two letters.',
          style: theme.textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Place place;

  const _ResultTile({required this.place});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final area = place.areaName;
    final distance = place.distanceMetres;
    final mode = RatrooTheme.modeColor(_modeOf(place.type));

    return InkWell(
      onTap: () => context.push('/place-details?id=${place.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RatrooTheme.space6,
          vertical: RatrooTheme.space3,
        ),
        child: Row(
          children: [
            // A small tinted glyph, not a photograph. Seven identical bus
            // photos down a list is wallpaper: it repeats what the row already
            // says and crowds out the name, which is the only thing a rider is
            // scanning for.
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: mode.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(RatrooTheme.radiusSm),
              ),
              child: Icon(modeIcon(place.type), size: 17, color: mode),
            ),
            const SizedBox(width: RatrooTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleCaseName(place.canonicalName),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  // The second line only appears when it adds something. It
                  // used to read "Bus stop" on every row beside a bus icon.
                  if (area != null)
                    Text(
                      area,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (distance != null) ...[
              const SizedBox(width: RatrooTheme.space3),
              Text(
                distanceLabel(distance),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
            const SizedBox(width: RatrooTheme.space2),
            Icon(
              AppIcons.chevron,
              size: 16,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.28),
            ),
          ],
        ),
      ),
    );
  }

  /// The stop category as a mode key the theme knows: BUS_STOP -> bus.
  static String _modeOf(String? category) => (category ?? '')
      .toLowerCase()
      .replaceAll(RegExp(r'_(stop|station|ghat)$'), '');
}
