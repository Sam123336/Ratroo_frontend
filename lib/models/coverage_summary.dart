/// What Ratroo covers around a point, as the data actually stands.
///
/// Every field is counted from the stops and routes we hold. Nothing here is
/// a marketing claim: if a mode is missing from [modes], we have no routes of
/// that kind in the region and the app must not mention it.
class CoverageSummary {
  /// "West Bengal", "Karnataka", or null when no stop nearby names its state.
  final String? region;
  final String? stateCode;
  final int routeCount;

  /// Lower-case mode names: bus, ferry, rail, tram, metro.
  final List<String> modes;

  /// Every stop held in the region, including ones no trip calls at yet.
  final int stopCount;

  /// When the region's stop data was last touched by ingestion. Null when
  /// nothing has recorded a timestamp — the app then shows no freshness claim
  /// rather than inventing one.
  final DateTime? lastUpdated;

  /// Per-mode counts, busiest first. A mode absent from this list has no
  /// routes in the region; the home screen says so instead of showing a zero
  /// that looks like a loading state.
  final List<ModeCoverage> byMode;

  const CoverageSummary({
    this.region,
    this.stateCode,
    this.routeCount = 0,
    this.modes = const [],
    this.stopCount = 0,
    this.lastUpdated,
    this.byMode = const [],
  });

  /// Counts for one mode, or null when we hold no routes of that kind.
  ModeCoverage? mode(String name) {
    for (final entry in byMode) {
      if (entry.mode == name) return entry;
    }
    return null;
  }

  bool get hasCoverage => routeCount > 0 && region != null;

  /// "Bus, ferry, rail and tram" — sentence case, no Oxford comma.
  String get modesSentence {
    if (modes.isEmpty) return '';
    final labels = modes.map(_label).toList();
    final head = labels.first[0].toUpperCase() + labels.first.substring(1);
    if (labels.length == 1) return head;

    final rest = labels.sublist(1);
    final last = rest.removeLast();
    return rest.isEmpty ? '$head and $last' : '$head, ${rest.join(', ')} and $last';
  }

  static String _label(String mode) {
    switch (mode) {
      case 'rail':
        return 'rail';
      case 'metro':
        return 'metro';
      case 'ferry':
        return 'ferry';
      case 'tram':
        return 'tram';
      case 'bus':
        return 'bus';
      default:
        return mode;
    }
  }

  factory CoverageSummary.fromJson(Map<String, dynamic> json) {
    final rawModes = json['modes'];

    return CoverageSummary(
      region: json['region'] as String?,
      stateCode: json['stateCode'] as String?,
      routeCount: (json['routeCount'] as num?)?.toInt() ?? 0,
      modes: rawModes is List
          ? rawModes.whereType<String>().map((m) => m.toLowerCase()).toList()
          : const [],
      stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
      lastUpdated: DateTime.tryParse(json['lastUpdated'] as String? ?? ''),
      byMode: json['byMode'] is List
          ? (json['byMode'] as List)
              .whereType<Map<String, dynamic>>()
              .map(ModeCoverage.fromJson)
              .toList()
          : const [],
    );
  }
}

class ModeCoverage {
  final String mode;
  final int routeCount;

  /// Stops with scheduled service on this mode, which is smaller than the
  /// region's stop total — an unserved stop belongs to no mode.
  final int stopCount;

  const ModeCoverage({
    required this.mode,
    required this.routeCount,
    required this.stopCount,
  });

  factory ModeCoverage.fromJson(Map<String, dynamic> json) => ModeCoverage(
        mode: (json['mode'] as String? ?? '').toLowerCase(),
        routeCount: (json['routeCount'] as num?)?.toInt() ?? 0,
        stopCount: (json['stopCount'] as num?)?.toInt() ?? 0,
      );
}
