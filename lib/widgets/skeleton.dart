import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../core/theme.dart';

/// Loading placeholders shaped like the content that is coming.
///
/// Built with `skeletonizer`, which renders a real widget tree as bones rather
/// than asking us to hand-draw grey rectangles that resemble it. That matters
/// because a hand-drawn placeholder drifts the moment the real row changes —
/// which is exactly what happened to the version this replaces.
///
/// A centred spinner is the thing to avoid: on the planner's multi-second
/// search it reads as a hang, and it says nothing about what is arriving.
class SkeletonList extends StatelessWidget {
  final int count;

  /// The row to imitate. Defaults to the stop/route card used across the app.
  final Widget? item;
  final EdgeInsets padding;

  const SkeletonList({
    super.key,
    this.count = 5,
    this.item,
    this.padding = const EdgeInsets.all(RatrooTheme.space4),
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      // Bones are decorative; nothing here should be announced or tappable.
      ignoreContainers: false,
      enableSwitchAnimation: true,
      child: ListView.builder(
        padding: padding,
        itemCount: count,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: RatrooTheme.space3),
          child: item ?? const _SkeletonCard(),
        ),
      ),
    );
  }
}

/// The shape of a stop or route row: avatar, title, one line of detail.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RatrooTheme.space4),
        child: Row(
          children: [
            // Explicit neutral: CircleAvatar defaults to the scheme's primary,
            // so every loading row showed a solid saffron disc — a bone that
            // draws the eye is the opposite of a bone.
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.12),
            ),
            const SizedBox(width: RatrooTheme.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Real text, so the bones inherit the real line heights.
                  Text('Placeholder stop name', style: theme.textTheme.titleMedium),
                  const SizedBox(height: RatrooTheme.space2),
                  Text('Bus stop · 1.2 km', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: RatrooTheme.space4),
            Text('1.2 km', style: theme.textTheme.titleSmall),
          ],
        ),
      ),
    );
  }
}
