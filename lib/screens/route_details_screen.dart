import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_providers.dart';
import '../models/route.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../widgets/glass_container.dart';
import '../widgets/confidence_gauge.dart';

final routeDetailsProvider = FutureProvider.autoDispose.family<ApiResponse<RouteModel>, String>((ref, routeId) async {
  final service = ref.watch(transitServiceProvider);
  return await service.getRouteDetails(routeId);
});

class RouteDetailsScreen extends ConsumerWidget {
  final String? routeId;
  
  const RouteDetailsScreen({super.key, this.routeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (routeId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Route & Reliability')),
        body: const Center(
          child: Text('No route ID was provided. Please select a valid route.'),
        ),
      );
    }
    final routeDetailsAsync = ref.watch(routeDetailsProvider(routeId!));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Route & Reliability'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          ),
        ],
      ),
      body: routeDetailsAsync.when(
        data: (response) {
          final route = response.data;
          if (route == null) {
            return _buildErrorState(context, 'Route details not found.');
          }
          final confidence = response.metadata?.confidenceScore ?? 0.95;
          return _buildContent(context, ref, route, confidence);
        },
        loading: () => _buildShimmerLoading(context),
        error: (err, stack) => _buildErrorState(context, err.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, RouteModel route, double confidence) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Placeholder Header
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
              image: const DecorationImage(
                image: NetworkImage('https://tile.openstreetmap.org/13/22.5726/88.3639.png'), // Mock tile map background snippet
                fit: BoxFit.cover,
                opacity: 0.3,
              ),
            ),
            child: Center(
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, color: theme.colorScheme.primary, size: 18),
                    const SizedBox(width: 8),
                    const Text('Live Route Path', style: TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route info title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            route.routeCode,
                            style: theme.textTheme.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${route.originName} to ${route.destinationName}',
                            style: TextStyle(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        route.providerCode,
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ).animate().slideX(begin: -0.1, end: 0),

                const SizedBox(height: 24),

                // High Confidence card
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: RatrooTheme.confidence(confidence).$1,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              confidence >= 0.8 ? 'High Confidence' : 'Moderate Confidence',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            Text(
                              'Real-time verified via ${route.providerCode} Live API',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                            ),
                          ],
                        ),
                      ),
                      ConfidenceGauge(score: confidence),
                    ],
                  ),
                ).animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 32),

                // Intermediate Stops Timeline
                Text(
                  'Upcoming Stops',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                _buildStopsTimeline(context, route),

                const SizedBox(height: 32),

                // Seat reservation green button CTA
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seat reservation is not enabled for this route.')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: RatrooTheme.confidenceHighFill,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Reserve Seat',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, size: 18),
                      ],
                    ),
                  ),
                ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 20),

                // Timetable deep link
                Center(
                  child: TextButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text('View official timetable on ${route.providerCode}'),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStopsTimeline(BuildContext context, RouteModel route) {
    // Generate complete list of stops: Origin -> Vias -> Destination
    final allStops = [
      route.originName,
      ...route.viaPoints,
      route.destinationName,
    ];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: allStops.length,
      itemBuilder: (context, index) {
        final stopName = allStops[index];
        final isFirst = index == 0;
        final isLast = index == allStops.length - 1;

        return IntrinsicHeight(
          child: Row(
            children: [
              // Left time indicator
              SizedBox(
                width: 70,
                child: Text(
                  isFirst
                      ? 'Origin'
                      : isLast
                          ? 'Dest.'
                           : 'Stop $index',
                  style: TextStyle(
                    fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.normal,
                    color: isFirst || isLast ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                ),
              ),
              // Timeline Node Line & Circle
              Column(
                children: [
                  Container(
                    width: 2,
                    height: 16,
                    color: isFirst ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                  ),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: isFirst || isLast ? Theme.of(context).primaryColor : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : Colors.grey.withValues(alpha: 0.3),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              // Stop text details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: InkWell(
                    onTap: () => context.push('/place-details?id=$stopName'),
                    child: Text(
                      stopName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (index * 100).ms);
      },
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(height: 180, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 32, width: 200, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                Container(height: 20, width: 150, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 24),
                Container(height: 80, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 32),
                Container(height: 24, width: 120, color: Colors.grey.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                ...List.generate(3, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(height: 50, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
                )),
              ],
            ),
          )
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 1200.ms, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05));
  }

  Widget _buildErrorState(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              'Failed to load route details:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to invalidate route Details')),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
