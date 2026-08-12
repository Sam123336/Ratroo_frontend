import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../providers/api_providers.dart';

/// One stop, as a place worth going to.
class TravelSpot {
  final String id;
  final String name;
  final String? area;

  const TravelSpot({required this.id, required this.name, this.area});
}

/// The stops of one mode, for browsing rather than counting.
///
/// Ferry ghats, tram stops and stations number in the tens, so they can be
/// shown as destinations. Bus stops cannot — 2,150 of them is a list nobody
/// reads — which is why this is only used for the small modes.
final travelSpotsProvider = FutureProvider.autoDispose
    .family<List<TravelSpot>, String>((ref, mode) async {
      final client = ref.watch(apiClientProvider);
      try {
        final response = await client.client.get(
          '/stops/by-mode',
          queryParameters: {'mode': mode.toUpperCase(), 'limit': 12},
        );
        final rows =
            (response.data['data']?['data'] ?? response.data['data']) as List?;
        return (rows ?? [])
            .whereType<Map<String, dynamic>>()
            .map(
              (row) => TravelSpot(
                id: row['id'] as String? ?? '',
                name: titleCaseName(row['name'] as String? ?? ''),
                area: row['area'] as String?,
              ),
            )
            .where((spot) => spot.id.isNotEmpty && spot.name.isNotEmpty)
            .toList();
      } catch (_) {
        // A carousel is decoration on top of the counts above it; failing to load
        // one must not take the card down.
        return const [];
      }
    });

/// A slowly advancing strip of places you can reach on one mode.
class SpotCarousel extends ConsumerStatefulWidget {
  final String mode;
  final Color colour;

  const SpotCarousel({super.key, required this.mode, required this.colour});

  @override
  ConsumerState<SpotCarousel> createState() => _SpotCarouselState();
}

class _SpotCarouselState extends ConsumerState<SpotCarousel> {
  final _controller = ScrollController();
  Timer? _timer;

  /// Started only once there is something to scroll.
  ///
  /// A periodic timer running behind an empty strip keeps the widget alive for
  /// nothing, and in tests it outlives the tree the binding is tearing down.
  void _ensureTicking() {
    if (_timer != null) return;
    // Never auto-advances under reduce motion: a strip that moves on its own
    // is exactly what that setting exists to stop.
    if (MediaQuery.disableAnimationsOf(context)) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _advance());
  }

  void _advance() {
    if (!_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    // Wraps to the start, so it reads as a loop rather than an end.
    final next = _controller.offset + 168 >= max
        ? 0.0
        : _controller.offset + 168;
    _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots =
        ref.watch(travelSpotsProvider(widget.mode)).valueOrNull ?? const [];
    if (spots.isEmpty) return const SizedBox.shrink();
    _ensureTicking();

    return SizedBox(
      height: 72,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RatrooTheme.space6),
        itemCount: spots.length,
        separatorBuilder: (_, _) => const SizedBox(width: RatrooTheme.space2),
        itemBuilder: (context, index) {
          final spot = spots[index];
          return InkWell(
            borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
            onTap: () => context.push('/place-details?id=${spot.id}'),
            child: Container(
              width: 156,
              padding: const EdgeInsets.all(RatrooTheme.space3),
              decoration: BoxDecoration(
                color: widget.colour.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(RatrooTheme.radiusMd),
                border: Border.all(
                  color: widget.colour.withValues(alpha: 0.16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    spot.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                  if (spot.area != null)
                    Text(
                      spot.area!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
