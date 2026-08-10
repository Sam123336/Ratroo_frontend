import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../models/journey.dart';
import '../core/app_icons.dart';

/// One journey option: a summary strip, then a leg-by-leg timeline.
///
/// Modelled on the reference board: when it leaves, what to board, where it
/// goes, how long. Times come from the operator's timetable and are simply
/// absent on services that publish none — never computed from the journey's
/// own estimate, which would look identical to a real departure.
class JourneyCard extends StatelessWidget {
  final JourneyPlanModel plan;

  /// Highlights the first option. The planner returns them fastest first, then
  /// by departure — so this is a statement about ordering, not a quality score.
  final bool isBest;

  const JourneyCard({super.key, required this.plan, this.isBest = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: RatrooTheme.space4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(RatrooTheme.radiusLg),
        border: Border.all(
          color: isBest
              ? RatrooTheme.primaryColor.withValues(alpha: 0.45)
              : theme.colorScheme.onSurface.withValues(alpha: 0.08),
          width: isBest ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summary(theme),
          Divider(height: 1, color: theme.colorScheme.onSurface.withValues(alpha: 0.06)),
          Padding(
            padding: const EdgeInsets.all(RatrooTheme.space4),
            child: Column(
              children: [
                for (var i = 0; i < plan.legs.length; i++)
                  _LegRow(leg: plan.legs[i], isLast: i == plan.legs.length - 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(ThemeData theme) {
    final fare = plan.fareLabel;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          RatrooTheme.space4, RatrooTheme.space4, RatrooTheme.space4, RatrooTheme.space3),
      child: Row(
        children: [
          if (isBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              margin: const EdgeInsets.only(right: RatrooTheme.space3),
              decoration: BoxDecoration(
                color: RatrooTheme.accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(RatrooTheme.radiusPill),
              ),
              child: Text(
                'Fastest',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: RatrooTheme.accentDeep,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          // The departure leads when the operator publishes one: "which bus,
          // when" is the question, and duration alone never answered it.
          if (plan.departureTime != null) ...[
            Text(plan.departureTime!, style: theme.textTheme.titleLarge),
            const SizedBox(width: RatrooTheme.space2),
            Text(plan.durationLabel, style: theme.textTheme.labelMedium),
          ] else
            Text(plan.durationLabel, style: theme.textTheme.titleLarge),
          const Spacer(),
          if (fare != null) ...[
            Text(fare, style: theme.textTheme.titleMedium),
            const SizedBox(width: RatrooTheme.space2),
          ],
          Text(
            plan.transfers == 0
                ? 'Direct'
                : '${plan.transfers} ${plan.transfers == 1 ? "transfer" : "transfers"}',
            style: theme.textTheme.labelMedium,
          ),
        ],
      ),
    );
  }
}

/// One leg: a coloured mode rail on the left, what to do on the right.
class _LegRow extends StatelessWidget {
  final JourneyLegModel leg;
  final bool isLast;

  const _LegRow({required this.leg, required this.isLast});

  static const _icons = {
    'bus': AppIcons.bus,
    'rail': AppIcons.rail,
    'metro': AppIcons.metro,
    'ferry': AppIcons.ferry,
    'tram': AppIcons.tram,
    'walk': AppIcons.walk,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = RatrooTheme.modeColor(leg.modeKey);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colour.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icons[leg.modeKey] ?? AppIcons.bus,
                      size: 17, color: colour),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      // Walking legs are dashed in spirit: a lighter rail marks
                      // the part of the trip with no vehicle.
                      color: colour.withValues(alpha: leg.isWalk ? 0.25 : 0.55),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: RatrooTheme.space3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : RatrooTheme.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Boarding time first on a timed service, as on a
                      // printed timetable.
                      if (leg.departureTime != null) ...[
                        Text(leg.departureTime!,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
                        const SizedBox(width: RatrooTheme.space2),
                      ],
                      Expanded(
                        child: Text(
                          leg.isWalk ? leg.walkLabel : (leg.routeCode ?? 'Service'),
                          style: theme.textTheme.titleSmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: RatrooTheme.space2),
                      Text(leg.durationLabel, style: theme.textTheme.labelMedium),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    leg.isWalk
                        ? 'to ${leg.toName}'
                        : '${leg.fromName} → ${leg.toName}',
                    style: theme.textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // Only offered when the API gave us a route to open.
                  if (leg.routeId != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: InkWell(
                        onTap: () => context.push('/route-details?id=${leg.routeId}'),
                        child: Text(
                          'See all stops',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: RatrooTheme.primaryColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
