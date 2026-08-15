import 'package:flutter/material.dart';
import 'app_icons.dart';
import 'theme.dart';

/// Icon for a stop category, as `/v1/stops/nearby` and `/v1/places/:id` report
/// it: `<routeType>_STOP` — BUS_STOP, RAIL_STOP, FERRY_STOP, TRAM_STOP.
///
/// Every list drew a bus, so tram stops and ferry ghats looked like bus stops.
/// Shared so the nearby list and the detail screen cannot drift apart again.
/// The stop's mode as a tinted circular glyph.
///
/// Was a photograph per mode. Four stock images of vehicles said nothing a
/// rider could act on, repeated identically down every list, and shipped
/// megabytes to say what a 20px icon says better.
class ModeAvatar extends StatelessWidget {
  /// API stop category — `BUS_STOP`, `FERRY_GHAT`, … Also accepts a bare mode
  /// key (`bus`, `rail`) via [ModeAvatar.forMode].
  final String? category;
  final double size;

  /// Rounded square instead of a circle, for the coverage grid's plate.
  final bool rounded;

  const ModeAvatar({
    super.key,
    required this.category,
    this.size = 48,
    this.rounded = false,
  });

  /// When the caller holds the bare mode key rather than the API's
  /// `<TYPE>_STOP` category — the coverage grid, which reads `byMode`.
  const ModeAvatar.forMode(
    String mode, {
    super.key,
    this.size = 48,
    this.rounded = false,
  }) : category = mode;

  /// [category] may arrive as either spelling, so normalise both.
  String? get _mode {
    final fromCategory = modeKey(category);
    if (fromCategory != null) return fromCategory;
    final bare = category?.toLowerCase();
    return RatrooTheme.modeColors.containsKey(bare) ? bare : null;
  }

  @override
  Widget build(BuildContext context) {
    // The mode's own colour, not the brand's.
    //
    // This drew the right glyph per mode and then painted every one of them
    // `colorScheme.primary` — so a tram stop, a ferry ghat and a bus stop were
    // the same colour, and the mode was carried by a 24px silhouette alone.
    // Once the brand went saffron it got worse: every list row matched the
    // selected tab and the primary button, so a *stop* looked like an *action*.
    final mode = _mode;
    final colour = RatrooTheme.modeColor(mode);

    final glyph = Center(
      child: Icon(modeIconFor(mode), color: colour, size: size * 0.5),
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(rounded ? size * 0.28 : size),
      ),
      // The generated illustration when present, the tinted glyph until then.
      //
      // These are detailed night scenes, so they only read at the sizes this
      // widget is used at — 44px in the coverage grid, 48px in a list row.
      // `errorBuilder` means dropping the PNG into assets/brand/ is the only
      // step; with no file this is exactly the glyph that shipped before.
      child: mode == null
          ? glyph
          : Padding(
              // The art is a transparent cut-out, so `contain` shows the whole
              // vehicle and the plate's mode tint reads through behind it.
              // `cover` is for full-bleed scenes and would crop the nose off.
              padding: EdgeInsets.all(size * 0.08),
              child: Image.asset(
                'assets/brand/mode_$mode.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => glyph,
              ),
            ),
    );
  }
}

/// The `modeColors` key for a stop category.
///
/// The API sends `<routeType>_STOP`; [RatrooTheme.modeColor] is keyed on the
/// bare route type. Anything unrecognised returns null so the colour falls
/// back to neutral rather than claiming a mode.
String? modeKey(String? category) {
  switch (category) {
    case 'RAIL_STOP':
    case 'RAIL_STATION':
      return 'rail';
    case 'FERRY_STOP':
    case 'FERRY_GHAT':
      return 'ferry';
    case 'TRAM_STOP':
      return 'tram';
    case 'METRO_STOP':
    case 'METRO_STATION':
      return 'metro';
    case 'AUTO_STAND':
      return 'auto';
    case 'SHARED_AUTO_STAND':
      return 'shared_auto';
    case 'BUS_STOP':
      return 'bus';
    default:
      return null;
  }
}

/// Glyph for a bare mode key — `bus`, `rail`, `shared_auto`.
IconData modeIconFor(String? mode) => switch (mode) {
      'rail' => AppIcons.rail,
      'ferry' => AppIcons.ferry,
      'tram' => AppIcons.tram,
      'metro' => AppIcons.metro,
      'auto' => AppIcons.auto,
      'shared_auto' => AppIcons.sharedAuto,
      'bus' => AppIcons.bus,
      // Generic "STOP", or a mode we do not know: claim nothing.
      _ => AppIcons.place,
    };

/// Glyph for an API stop category — `BUS_STOP`, `FERRY_GHAT`, …
///
/// Delegates rather than switching again. There were two switches over the
/// same seven modes, and [ModeAvatar] calling the category one with a bare key
/// fell through to the generic pin — every tile in the coverage grid drew a
/// map pin instead of its vehicle.
IconData modeIcon(String? category) => modeIconFor(modeKey(category));
