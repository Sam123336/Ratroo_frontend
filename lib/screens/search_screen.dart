import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/theme.dart';
import '../core/transit_icons.dart';
import '../models/place.dart';
import '../providers/api_providers.dart';

final _searchResultsProvider =
    FutureProvider.autoDispose.family<ApiResponse<List<Place>>, String>((ref, query) async {
  if (query.trim().length < 2) return ApiResponse(success: true, data: const []);
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
                RatrooTheme.space4, 0, RatrooTheme.space4, RatrooTheme.space3),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Stop, station or ghat',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
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

    return ref.watch(_searchResultsProvider(_query)).when(
          data: (response) {
            final places = response.data ?? const <Place>[];
            if (places.isEmpty) {
              return _message(
                theme,
                Icons.search_off,
                'Nothing matches "${_query.trim()}".',
                'Try the stop name as it is written on the bus, or a nearby landmark.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: RatrooTheme.space4),
              itemCount: places.length,
              separatorBuilder: (_, _) => Divider(
                height: 1,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              itemBuilder: (context, index) => _ResultTile(place: places[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => _message(theme, Icons.wifi_off, 'Search failed.', '$err'),
        );
  }

  Widget _intro(ThemeData theme) {
    final area = ref.watch(userLocationProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      children: [
        const SizedBox(height: RatrooTheme.space8),
        Icon(Icons.travel_explore,
            size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: RatrooTheme.space4),
        Text('Search any stop in the network',
            style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
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

  Widget _message(ThemeData theme, IconData icon, String title, String detail) {
    return ListView(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      children: [
        const SizedBox(height: RatrooTheme.space8),
        Icon(icon, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.25)),
        const SizedBox(height: RatrooTheme.space4),
        Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
        const SizedBox(height: RatrooTheme.space2),
        Text(detail, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final Place place;

  const _ResultTile({required this.place});

  @override
  Widget build(BuildContext context) {
    final area = place.areaName;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: RatrooTheme.space2),
      leading: ModeAvatar(category: place.type, size: 42),
      title: Text(place.canonicalName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        area == null ? place.readableType : '${place.readableType} · $area',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () => context.push('/place-details?id=${place.id}'),
    );
  }
}
