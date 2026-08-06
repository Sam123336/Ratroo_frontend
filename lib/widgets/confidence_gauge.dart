import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme.dart';

class ConfidenceGauge extends StatelessWidget {
  final double score; // 0.0 to 1.0

  const ConfidenceGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    // Ring uses the saturated fill, the label its darker pair — the yellow fill
    // is ~1.8:1 on white and unreadable at 12px.
    final (fill, labelColor) = RatrooTheme.confidence(score);
    final percent = (score * 100).toInt();

    return Semantics(
      label: 'Reliability $percent percent',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              value: score,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
              backgroundColor: fill.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(fill),
            ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
          ),
          const SizedBox(width: RatrooTheme.space2),
          Text(
            '$percent% Reliable',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: labelColor),
          ).animate().fadeIn(delay: 300.ms),
        ],
      ),
    );
  }
}
