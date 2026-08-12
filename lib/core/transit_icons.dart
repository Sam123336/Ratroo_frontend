import 'package:flutter/material.dart';
import 'app_icons.dart';

/// Icon for a stop category, as `/v1/stops/nearby` and `/v1/places/:id` report
/// it: `<routeType>_STOP` — BUS_STOP, RAIL_STOP, FERRY_STOP, TRAM_STOP.
///
/// Every list drew a bus, so tram stops and ferry ghats looked like bus stops.
/// Shared so the nearby list and the detail screen cannot drift apart again.
/// Photo of the vehicle for a stop category, or null when there is none.
///
/// Only the modes we hold a picture for. A generic "STOP" gets no photo,
/// because guessing which vehicle to show is the same mistake as labelling
/// every stop a bus stop.
String? modePhoto(String? category) {
  switch (category) {
    case 'BUS_STOP':
      return 'assets/brand/mode_bus.jpg';
    case 'RAIL_STOP':
    case 'RAIL_STATION':
      return 'assets/brand/mode_rail.jpg';
    case 'FERRY_STOP':
    case 'FERRY_GHAT':
      return 'assets/brand/mode_ferry.jpg';
    case 'TRAM_STOP':
      return 'assets/brand/mode_tram.jpg';
    default:
      return null;
  }
}

/// Circular photo of the vehicle, falling back to the tinted glyph.
class ModeAvatar extends StatelessWidget {
  final String? category;
  final double size;

  const ModeAvatar({super.key, required this.category, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = modePhoto(category);

    final glyph = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(modeIcon(category), color: theme.colorScheme.primary, size: size * 0.5),
    );

    if (photo == null) return glyph;

    return ClipOval(
      child: Image.asset(
        photo,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // A missing asset must not blank out the whole list.
        errorBuilder: (_, _, _) => glyph,
      ),
    );
  }
}

IconData modeIcon(String? category) {
  switch (category) {
    case 'RAIL_STOP':
    case 'RAIL_STATION':
      return AppIcons.rail;
    case 'FERRY_STOP':
    case 'FERRY_GHAT':
      return AppIcons.ferry;
    case 'TRAM_STOP':
      return AppIcons.tram;
    case 'METRO_STOP':
    case 'METRO_STATION':
      return AppIcons.metro;
    case 'AUTO_STAND':
      return AppIcons.auto;
    case 'SHARED_AUTO_STAND':
      return AppIcons.sharedAuto;
    case 'BUS_STOP':
      return AppIcons.bus;
    default:
      // Generic "STOP", or a category we do not know: claim nothing.
      return AppIcons.place;
  }
}
