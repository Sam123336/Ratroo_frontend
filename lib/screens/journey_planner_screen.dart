import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_providers.dart';
import '../models/journey.dart';
import '../widgets/journey_card.dart';
import '../widgets/skeleton.dart';
import '../core/transit_icons.dart';
import '../models/place.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../widgets/glass_container.dart';
import '../core/app_icons.dart';
import '../widgets/status_view.dart';

// State providers for search input and focus
final fromSearchQueryProvider = StateProvider<String>((ref) => '');
final toSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedFromPlaceProvider = StateProvider<Place?>((ref) => null);
final selectedToPlaceProvider = StateProvider<Place?>((ref) => null);
final activeSearchFieldProvider = StateProvider<String?>(
  (ref) => null,
); // 'from', 'to', or null

// FutureProvider for search suggestions
final searchSuggestionsProvider = FutureProvider.autoDispose
    .family<ApiResponse<List<Place>>, String>((ref, query) async {
      if (query.trim().isEmpty) return ApiResponse(success: true, data: []);
      final searchService = ref.watch(searchServiceProvider);
      return await searchService.searchPlaces(query);
    });

/// The stop the user is standing closest to, widening the search until it
/// finds one. Used to fill "From" so nobody has to type where they already are.
final nearestStopProvider = FutureProvider.autoDispose<Place?>((ref) async {
  final location = await ref.watch(userLocationProvider.future);
  if (!location.isLive) return null; // Never guess from the Kolkata fallback.

  final result = await ref
      .watch(nearbyServiceProvider)
      .findNearest(location.latitude, location.longitude);

  return result.data?.places.firstOrNull;
});

/// Where you can actually get to from a stop, in one ride.
///
/// Taken from the destinations of the services that call there — the headsign
/// of each departure, then the far end of each route. Nothing is inferred:
/// every name here is the end of a real service from this stop.
final reachableFromProvider = FutureProvider.autoDispose
    .family<List<String>, String>((ref, stopId) async {
      final response = await ref
          .watch(searchServiceProvider)
          .getPlaceById(stopId);
      final place = response.data;
      if (place == null) return const [];

      final seen = <String>{};
      final destinations = <String>[];

      void add(String? name) {
        final value = name?.trim();
        if (value == null || value.isEmpty) return;
        // Where you already are is not somewhere to go.
        if (value.toLowerCase() == place.canonicalName.toLowerCase()) return;
        if (seen.add(value.toLowerCase())) destinations.add(value);
      }

      for (final departure in place.departures) {
        add(departure.headsign);
      }
      for (final route in place.routes) {
        add(route.shortLabelAt(place.canonicalName));
      }

      return destinations;
    });

// FutureProvider for final journey plans
final journeyResultsProvider =
    FutureProvider.autoDispose<ApiResponse<List<JourneyPlanModel>>>((
      ref,
    ) async {
      final fromPlace = ref.watch(selectedFromPlaceProvider);
      final toPlace = ref.watch(selectedToPlaceProvider);
      if (fromPlace == null || toPlace == null) {
        return ApiResponse(success: true, data: []);
      }
      final journeyService = ref.watch(journeyServiceProvider);
      // The API planner expects place names (titles) rather than place UUIDs in the database
      return await journeyService.getJourneyPlan(
        fromPlace.canonicalName,
        toPlace.canonicalName,
      );
    });

class JourneyPlannerScreen extends ConsumerStatefulWidget {
  const JourneyPlannerScreen({super.key});

  @override
  ConsumerState<JourneyPlannerScreen> createState() =>
      _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends ConsumerState<JourneyPlannerScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  String _selectedFilter = 'Fastest';

  /// Set once the nearest stop has been used to fill "From", so a later
  /// location refresh cannot overwrite something the user typed.
  bool _prefilled = false;

  /// Fills "From" with the nearest stop. Silent when the user has already
  /// typed there, or when we have no live fix — filling in the Kolkata
  /// fallback would send someone in Bardhaman on a journey from Esplanade.
  void _prefillFrom(Place stop) {
    if (_prefilled || _fromController.text.isNotEmpty) return;
    _prefilled = true;
    _fromController.text = stop.canonicalName;
    ref.read(selectedFromPlaceProvider.notifier).state = stop;
  }

  @override
  void initState() {
    super.initState();
    _fromFocus.addListener(() {
      if (_fromFocus.hasFocus) {
        ref.read(activeSearchFieldProvider.notifier).state = 'from';
      }
    });
    _toFocus.addListener(() {
      if (_toFocus.hasFocus) {
        ref.read(activeSearchFieldProvider.notifier).state = 'to';
      }
    });
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeField = ref.watch(activeSearchFieldProvider);
    final fromQuery = ref.watch(fromSearchQueryProvider);
    final toQuery = ref.watch(toSearchQueryProvider);

    final selectedFrom = ref.watch(selectedFromPlaceProvider);
    final selectedTo = ref.watch(selectedToPlaceProvider);

    final showJourneyResults = selectedFrom != null && selectedTo != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journey Planner'),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search input box
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // From Field
                  Row(
                    children: [
                      Icon(
                        AppIcons.myLocation,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _fromController,
                          focusNode: _fromFocus,
                          onChanged: (val) {
                            ref.read(fromSearchQueryProvider.notifier).state =
                                val;
                            if (ref.read(selectedFromPlaceProvider) != null) {
                              ref
                                      .read(selectedFromPlaceProvider.notifier)
                                      .state =
                                  null;
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Enter departure place...',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_fromController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(AppIcons.clear, size: 18),
                          onPressed: () {
                            _fromController.clear();
                            ref.read(fromSearchQueryProvider.notifier).state =
                                '';
                            ref.read(selectedFromPlaceProvider.notifier).state =
                                null;
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  // To Field
                  Row(
                    children: [
                      const Icon(
                        AppIcons.place,
                        color: RatrooTheme.confidenceLowFill,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _toController,
                          focusNode: _toFocus,
                          onChanged: (val) {
                            ref.read(toSearchQueryProvider.notifier).state =
                                val;
                            if (ref.read(selectedToPlaceProvider) != null) {
                              ref.read(selectedToPlaceProvider.notifier).state =
                                  null;
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Where to?',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_toController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(AppIcons.clear, size: 18),
                          onPressed: () {
                            _toController.clear();
                            ref.read(toSearchQueryProvider.notifier).state = '';
                            ref.read(selectedToPlaceProvider.notifier).state =
                                null;
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Search Suggestions Dropdown Overlay List
          if (activeField != null && !showJourneyResults)
            Expanded(
              child: _buildSuggestionsList(
                activeField == 'from' ? fromQuery : toQuery,
                activeField,
              ),
            ),

          // Journey Results Display
          if (showJourneyResults) ...[
            _buildFilters(),
            Expanded(
              child: ref
                  .watch(journeyResultsProvider)
                  .when(
                    data: (response) {
                      final plans = response.data ?? [];
                      if (plans.isEmpty) {
                        return _buildEmptyState(response.error);
                      }
                      return _buildPlansList(
                        plans,
                        response.metadata?.confidenceScore ?? 1.0,
                      );
                    },
                    loading: () => const SkeletonList(count: 3),
                    error: (err, _) => _buildErrorState(err),
                  ),
            ),
          ],

          // Was a line of grey text telling the user to type. It now offers
          // the nearest stop and the places you can actually reach from it.
          if (activeField == null && !showJourneyResults)
            Expanded(child: _buildStartSuggestions()),
        ],
      ),
    );
  }

  /// The opening state: your nearest stop, and where its services go.
  Widget _buildStartSuggestions() {
    final theme = Theme.of(context);

    return ref
        .watch(nearestStopProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _startHint(theme),
          data: (stop) {
            if (stop == null) return _startHint(theme);

            // Fill "From" as soon as we know where they are. Deferred to after
            // the frame: setting a controller during build throws.
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _prefillFrom(stop),
            );

            return ListView(
              padding: const EdgeInsets.all(RatrooTheme.space4),
              children: [
                Row(
                  children: [
                    const Icon(
                      AppIcons.myLocation,
                      size: 18,
                      color: RatrooTheme.primaryColor,
                    ),
                    const SizedBox(width: RatrooTheme.space2),
                    Expanded(
                      child: Text(
                        'Nearest stop: ${stop.canonicalName}'
                        '${stop.distanceLabel == null ? "" : " · ${stop.distanceLabel}"}',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: RatrooTheme.space4),
                _reachableSection(stop, theme),
              ],
            );
          },
        );
  }

  /// Where a rider can actually get to from [stop], in one ride.
  ///
  /// Shown in two places: before anything is chosen, against the nearest stop,
  /// and again once an origin is set and the "To" field is empty — which is
  /// where it was missing. Picking a departure and then being told to "type to
  /// search" wastes the one thing the app just learned.
  Widget _reachableSection(Place stop, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Where you can go from ${stop.canonicalName}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: RatrooTheme.space1),
        Text(
          // Named for what it is: these are one-seat rides, not the full set
          // of places reachable with a change.
          'Direct services from this stop.',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: RatrooTheme.space3),
        ref
            .watch(reachableFromProvider(stop.id))
            .when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: RatrooTheme.space4),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, _) => Text(
                'Could not load destinations.',
                style: theme.textTheme.bodyMedium,
              ),
              data: (destinations) {
                if (destinations.isEmpty) {
                  return Text(
                    'No services from ${stop.canonicalName} are mapped yet, '
                    'so type a destination instead.',
                    style: theme.textTheme.bodyMedium,
                  );
                }

                return Wrap(
                  spacing: RatrooTheme.space2,
                  runSpacing: RatrooTheme.space2,
                  children: [
                    for (final destination in destinations.take(16))
                      ActionChip(
                        label: Text(destination),
                        avatar: const Icon(AppIcons.forward, size: 15),
                        onPressed: () => _planTo(destination),
                      ),
                  ],
                );
              },
            ),
      ],
    );
  }

  /// Fills "To" with a suggested destination and plans straight away — the
  /// point of a suggestion is not having to type it.
  void _planTo(String destination) {
    _toController.text = destination;
    ref.read(selectedToPlaceProvider.notifier).state = Place(
      id: '',
      canonicalName: destination,
    );
    ref.read(activeSearchFieldProvider.notifier).state = null;
    _toFocus.unfocus();
    setState(() {});
  }

  Widget _startHint(ThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(RatrooTheme.space6),
      child: Text(
        'Enter a departure and destination to plan your trip.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium,
      ),
    ),
  );

  Widget _buildSuggestionsList(String query, String field) {
    if (query.trim().isEmpty) {
      final theme = Theme.of(context);
      final origin = ref.watch(selectedFromPlaceProvider);

      // An origin with an id is one we can ask about. A destination typed in
      // by hand has no id, and neither does the "From" field before a stop is
      // actually picked from the list.
      if (field == 'to' && origin != null && origin.id.isNotEmpty) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(RatrooTheme.space4),
          child: _reachableSection(origin, theme),
        );
      }

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(RatrooTheme.space6),
          child: Text(
            'Type to search stops or cities.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      );
    }

    final suggestionsAsync = ref.watch(searchSuggestionsProvider(query));

    return suggestionsAsync.when(
      data: (response) {
        final places = response.data ?? [];
        if (places.isEmpty) {
          return const Center(child: Text('No places found.'));
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: places.length,
          itemBuilder: (context, index) {
            final place = places[index];
            return ListTile(
              leading: Icon(
                modeIcon(place.type),
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.7),
              ),
              title: Text(place.canonicalName),
              subtitle: Text(place.readableType),
              onTap: () {
                if (field == 'from') {
                  _fromController.text = place.canonicalName;
                  ref.read(selectedFromPlaceProvider.notifier).state = place;
                  _fromFocus.unfocus();
                  if (ref.read(selectedToPlaceProvider) == null) {
                    _toFocus.requestFocus();
                  }
                } else {
                  _toController.text = place.canonicalName;
                  ref.read(selectedToPlaceProvider.notifier).state = place;
                  _toFocus.unfocus();
                }
                ref.read(activeSearchFieldProvider.notifier).state = null;
              },
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildFilters() {
    final filters = ['Fastest', 'Cheapest', 'Least Walking'];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            selectedColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.2),
            onSelected: (selected) {
              if (selected) {
                setState(() {
                  _selectedFilter = filter;
                });
              }
            },
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPlansList(List<JourneyPlanModel> plans, double confidenceScore) {
    // Each option is a JourneyCard: duration, fare and transfers on top, then
    // the legs. The old card printed "Free / N/A" whenever the fare was 0,
    // which reads as a free bus rather than a missing price.
    return ListView.builder(
      padding: const EdgeInsets.all(RatrooTheme.space4),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        return JourneyCard(
          plan: plans[index],
          isBest: index == 0,
        ).animate().fadeIn(delay: (index * 90).ms).slideY(begin: 0.08, end: 0);
      },
    );
  }

  Widget _buildEmptyState(String? error) {
    return StatusView(
      kind: StatusKind.noRoute,
      message: 'No connecting routes found.',
      // The planner's own explanation when it has one — "no service after
      // 21:40" is worth more to a rider than a generic shrug.
      detail: error ?? 'Try a nearby stop, or a different time of day.',
    );
  }

  Widget _buildErrorState(Object error) {
    return StatusView.fromError(
      error,
      message: 'Could not plan this trip.',
      onRetry: () => ref.invalidate(journeyResultsProvider),
    );
  }
}
