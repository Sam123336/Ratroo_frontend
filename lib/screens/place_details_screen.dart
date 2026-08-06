import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/api_providers.dart';
import '../models/place.dart';
import '../core/theme.dart';
import '../core/api_client.dart';
import '../widgets/glass_container.dart';

final placeDetailsProvider = FutureProvider.autoDispose.family<ApiResponse<List<Place>>, String>((ref, id) async {
  final service = ref.watch(searchServiceProvider);
  return await service.searchPlaces(id);
});

class PlaceDetailsScreen extends ConsumerWidget {
  final String? placeId;
  
  const PlaceDetailsScreen({super.key, this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeName = placeId ?? "Arambagh";
    final placeDetailsAsync = ref.watch(placeDetailsProvider(placeName));

    return Scaffold(
      appBar: AppBar(
        title: Text(placeName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border),
            onPressed: () {},
          )
        ],
      ),
      body: placeDetailsAsync.when(
        data: (response) {
          final places = response.data ?? [];
          if (places.isEmpty) {
            return _buildEmptyState(context, placeName);
          }
          final place = places.first;
          final confidence = response.metadata?.confidenceScore ?? 0.95;
          final sources = response.metadata?.dataSources ?? ['Places Database'];

          return _buildContent(context, place, confidence, sources);
        },
        loading: () => _buildShimmerLoading(context),
        error: (err, stack) => _buildErrorState(context, err.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Place place, double confidence, List<String> sources) {
    final theme = Theme.of(context);
    final connectivityScore = (confidence * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Connectivity Score Card
          Center(
            child: GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
              child: Column(
                children: [
                  Text(
                    'Connectivity Index',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '$connectivityScore',
                    style: theme.textTheme.displayLarge?.copyWith(
                      color: RatrooTheme.confidence(connectivityScore / 100).$2,
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ).animate().scale(curve: Curves.easeOutBack),
          ),
          
          const SizedBox(height: 32),
          
          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatColumn(val: place.type == 'BUS_STOP' ? '1' : '0', label: 'Bus Station'),
              const _StatColumn(val: '96%', label: 'Reliability'),
              _StatColumn(val: place.lat != null ? 'Yes' : 'No', label: 'Geo Located'),
            ],
          ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 40),
          
          Text('Location Details', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
              .animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(label: 'Type', value: place.type ?? 'Transit Location'),
                const Divider(),
                _DetailRow(label: 'Latitude', value: place.lat?.toStringAsFixed(6) ?? 'N/A'),
                const Divider(),
                _DetailRow(label: 'Longitude', value: place.lon?.toStringAsFixed(6) ?? 'N/A'),
              ],
            ),
          ).animate().fadeIn(delay: 250.ms),
          
          const SizedBox(height: 40),
          
          Text('Verified Data Provenance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))
              .animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          GlassContainer(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ...sources.map((src) => Column(
                  children: [
                    _SourceRow(name: src, date: 'Sync Completed'),
                    if (src != sources.last) const Divider(),
                  ],
                )),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {},
                  child: const Text('Open Original Graph Sources'),
                )
              ],
            ),
          ).animate().fadeIn(delay: 350.ms),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            height: 180,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (i) => Container(height: 50, width: 80, color: Colors.grey.withValues(alpha: 0.1))),
          ),
          const SizedBox(height: 40),
          Container(height: 150, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
          const SizedBox(height: 40),
          Container(height: 120, width: double.infinity, color: Colors.grey.withValues(alpha: 0.1)),
        ],
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 1200.ms, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05));
  }

  Widget _buildEmptyState(BuildContext context, String placeName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'No details found for "$placeName".',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
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
              'Failed to load place details:\n$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String val;
  final String label;

  const _StatColumn({required this.val, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final String name;
  final String date;

  const _SourceRow({required this.name, required this.date});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.verified, size: 16, color: Colors.blue),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
