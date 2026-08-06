import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_providers.dart';
import '../models/journey.dart';
import '../models/place.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../widgets/glass_container.dart';
import '../widgets/confidence_gauge.dart';

// State providers for search input and focus
final fromSearchQueryProvider = StateProvider<String>((ref) => '');
final toSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedFromPlaceProvider = StateProvider<Place?>((ref) => null);
final selectedToPlaceProvider = StateProvider<Place?>((ref) => null);
final activeSearchFieldProvider = StateProvider<String?>((ref) => null); // 'from', 'to', or null

// FutureProvider for search suggestions
final searchSuggestionsProvider = FutureProvider.autoDispose.family<ApiResponse<List<Place>>, String>((ref, query) async {
  if (query.trim().isEmpty) return ApiResponse(success: true, data: []);
  final searchService = ref.watch(searchServiceProvider);
  return await searchService.searchPlaces(query);
});

// FutureProvider for final journey plans
final journeyResultsProvider = FutureProvider.autoDispose<ApiResponse<List<JourneyPlanModel>>>((ref) async {
  final fromPlace = ref.watch(selectedFromPlaceProvider);
  final toPlace = ref.watch(selectedToPlaceProvider);
  if (fromPlace == null || toPlace == null) {
    return ApiResponse(success: true, data: []);
  }
  final journeyService = ref.watch(journeyServiceProvider);
  // The API planner expects place names (titles) rather than place UUIDs in the database
  return await journeyService.getJourneyPlan(fromPlace.canonicalName, toPlace.canonicalName);
});

class JourneyPlannerScreen extends ConsumerStatefulWidget {
  const JourneyPlannerScreen({super.key});

  @override
  ConsumerState<JourneyPlannerScreen> createState() => _JourneyPlannerScreenState();
}

class _JourneyPlannerScreenState extends ConsumerState<JourneyPlannerScreen> {
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  String _selectedFilter = 'Fastest';

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
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          // Search input box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: GlassContainer(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // From Field
                  Row(
                    children: [
                      Icon(Icons.my_location, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _fromController,
                          focusNode: _fromFocus,
                          onChanged: (val) {
                            ref.read(fromSearchQueryProvider.notifier).state = val;
                            if (ref.read(selectedFromPlaceProvider) != null) {
                              ref.read(selectedFromPlaceProvider.notifier).state = null;
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
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _fromController.clear();
                            ref.read(fromSearchQueryProvider.notifier).state = '';
                            ref.read(selectedFromPlaceProvider.notifier).state = null;
                          },
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  // To Field
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: RatrooTheme.confidenceLowFill, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _toController,
                          focusNode: _toFocus,
                          onChanged: (val) {
                            ref.read(toSearchQueryProvider.notifier).state = val;
                            if (ref.read(selectedToPlaceProvider) != null) {
                              ref.read(selectedToPlaceProvider.notifier).state = null;
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
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _toController.clear();
                            ref.read(toSearchQueryProvider.notifier).state = '';
                            ref.read(selectedToPlaceProvider.notifier).state = null;
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
              child: ref.watch(journeyResultsProvider).when(
                    data: (response) {
                      final plans = response.data ?? [];
                      if (plans.isEmpty) {
                        return _buildEmptyState(response.error);
                      }
                      return _buildPlansList(plans, response.metadata?.confidenceScore ?? 1.0);
                    },
                    loading: () => _buildShimmerLoading(),
                    error: (err, stack) => _buildErrorState(err.toString()),
                  ),
            ),
          ],
          
          if (activeField == null && !showJourneyResults)
            const Expanded(
              child: Center(
                child: Text(
                  'Enter departure and destination points to plan your trip.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(String query, String field) {
    if (query.trim().isEmpty) {
      return const Center(child: Text('Type to search stops or cities...'));
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
                place.type == 'BUS_STOP' ? Icons.directions_bus : Icons.place,
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
              ),
              title: Text(place.canonicalName),
              subtitle: Text(place.type ?? 'Transit Location'),
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
            selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: plans.length,
      itemBuilder: (context, index) {
        final plan = plans[index];
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              final transitLegs = plan.legs.where((leg) => leg.routeId != null);
              if (transitLegs.isNotEmpty) {
                final routeId = transitLegs.first.routeId!;
                context.push('/route-details?id=$routeId');
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No route details available for walk-only legs.')),
                );
              }
            },
            borderRadius: BorderRadius.circular(24),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 20, color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            '${(plan.totalDurationSeconds / 60).round()} min',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Text(
                        plan.totalFare > 0 ? '₹${plan.totalFare.toStringAsFixed(0)}' : 'Free / N/A',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Visual multimodal timeline sequence
                  _buildTimelineSequence(plan.legs),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: Divider(),
                  ),
                  
                  Row(
                    children: [
                      const Icon(Icons.verified, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      // Expanded + ellipsis: long service names ("KOLKATA to
                      // ARAMBAG (NS)") pushed the gauge off-screen and the row
                      // overflowed by 11px.
                      Expanded(
                        child: Text(
                          _getProvenanceName(plan.legs),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConfidenceGauge(score: confidenceScore),
                    ],
                  )
                ],
              ),
            ),
          ).animate().fadeIn(delay: (index * 150).ms).slideY(begin: 0.1, end: 0),
        );
      },
    );
  }

  Widget _buildTimelineSequence(List<JourneyLegModel> legs) {
    return Row(
      children: legs.map((leg) {
        final isLast = leg == legs.last;
        return Expanded(
          flex: isLast ? 0 : 1,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _getModeColor(leg.mode).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(_getModeIcon(leg.mode), color: _getModeColor(leg.mode), size: 20),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    height: 2,
                    color: Colors.grey.withValues(alpha: 0.3),
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  IconData _getModeIcon(String mode) {
    switch (mode.toUpperCase()) {
      case 'BUS':
        return Icons.directions_bus;
      case 'FERRY':
        return Icons.directions_boat;
      case 'METRO':
        return Icons.subway;
      case 'WALK':
      default:
        return Icons.directions_walk;
    }
  }

  Color _getModeColor(String mode) {
    switch (mode.toUpperCase()) {
      case 'BUS':
        return Colors.blue;
      case 'FERRY':
        return Colors.cyan;
      case 'METRO':
        return Colors.purple;
      case 'WALK':
      default:
        return Colors.grey;
    }
  }

  String _getProvenanceName(List<JourneyLegModel> legs) {
    final activeLegs = legs.where((l) => l.routeCode != null);
    if (activeLegs.isEmpty) return 'Walk Journey';
    return 'Sources: ${activeLegs.map((l) => l.routeCode).toSet().join(", ")}';
  }

  Widget _buildShimmerLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(height: 24, width: 100, color: Colors.grey.withValues(alpha: 0.1)),
                    Container(height: 24, width: 60, color: Colors.grey.withValues(alpha: 0.1)),
                  ],
                ),
                const SizedBox(height: 20),
                Container(height: 30, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 20),
                Container(height: 20, width: 150, color: Colors.grey.withValues(alpha: 0.1)),
              ],
            ),
          ),
        ).animate(onPlay: (controller) => controller.repeat())
         .shimmer(duration: 1200.ms, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05));
      },
    );
  }

  Widget _buildEmptyState(String? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_off_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              error ?? 'No connecting routes found between these locations.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Trip Planning Error:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.invalidate(journeyResultsProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
