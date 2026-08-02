import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ConfidenceGauge extends StatelessWidget {
  final double score; // 0.0 to 1.0

  const ConfidenceGauge({super.key, required this.score});

  @override
  Widget build(BuildContext context) {
    Color gaugeColor;
    if (score >= 0.8) {
      gaugeColor = const Color(0xFF00B95C); // Green
    } else if (score >= 0.5) {
      gaugeColor = const Color(0xFFFBBC04); // Yellow
    } else {
      gaugeColor = const Color(0xFFFC413D); // Red
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            value: score,
            strokeWidth: 3,
            backgroundColor: gaugeColor.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
          ).animate().scale(delay: 200.ms, duration: 400.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).toInt()}% Reliable',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: gaugeColor,
          ),
        ).animate().fadeIn(delay: 300.ms),
      ],
    );
  }
}
