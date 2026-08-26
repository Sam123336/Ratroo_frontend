class JourneyPlanModel {
  final List<JourneyLegModel> legs;
  final int totalDurationSeconds;

  /// Sum of the priced legs. Null when no leg has a fare — never 0, which
  /// would read as free.
  final double? totalFare;

  /// True when some legs are unpriced, so [totalFare] is a floor, not a price.
  final bool fareIncomplete;

  /// e.g. ESTIMATED_BY_DISTANCE. Most WBBus fares are derived, not official.
  final List<String> fareSources;
  final int transfers;
  final String? totalDistanceKm;

  JourneyPlanModel({
    required this.legs,
    required this.totalDurationSeconds,
    this.totalFare,
    this.fareIncomplete = false,
    this.fareSources = const [],
    this.transfers = 0,
    this.totalDistanceKm,
  });

  int get totalMinutes => (totalDurationSeconds / 60).round();

  /// "2h 35m" / "45m" — the headline figure on a result card.
  String get durationLabel {
    final minutes = totalMinutes;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  /// "₹65", "from ₹65" when some legs are unpriced, or null when none are.
  String? get fareLabel {
    final fare = totalFare;
    if (fare == null || fare <= 0) return null;
    final rounded = '₹${fare.round()}';
    return fareIncomplete ? 'from $rounded' : rounded;
  }

  bool get fareIsEstimated => fareSources.any((s) => s.contains('ESTIMATED'));

  /// When the first timed service leaves, or null when nothing on this
  /// journey has a published time.
  String? get departureTime {
    for (final leg in legs) {
      if (leg.departureTime != null) return leg.departureTime;
    }
    return null;
  }

  /// The modes used, in order, for the icon strip on a collapsed card.
  List<String> get modeSequence => legs.map((l) => l.mode).toList();

  // Backend (JourneyResponseDto) speaks minutes; this model speaks seconds.
  factory JourneyPlanModel.fromJson(Map<String, dynamic> json) {
    final rawSources = json['fareSources'];

    return JourneyPlanModel(
      legs: (json['legs'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(JourneyLegModel.fromJson)
              .toList() ??
          [],
      totalDurationSeconds: json['totalDurationSeconds'] ??
          ((json['totalDurationMinutes'] as num?)?.round() ?? 0) * 60,
      totalFare: (json['totalFare'] as num?)?.toDouble(),
      fareIncomplete: json['fareIncomplete'] == true,
      fareSources:
          rawSources is List ? rawSources.whereType<String>().toList() : const [],
      transfers: (json['transfersCount'] as num?)?.toInt() ?? 0,
      totalDistanceKm: json['totalDistanceKm']?.toString(),
    );
  }
}

class JourneyLegModel {
  /// WALK, BUS, SUBURBAN_RAIL, RAIL, METRO, FERRY, TRAM, AUTO, SHARED_AUTO.
  ///
  /// AUTO and SHARED_AUTO arrive from operator-registered services, and are
  /// kept distinct all the way to the icon: the backend stopped flattening
  /// them into BUS, and this must not put it back.
  final String mode;
  final String fromPlaceId;
  final String toPlaceId;
  final String fromName;
  final String toName;
  final String? routeId;
  final String? routeCode;

  /// The operator, e.g. WBBUS — shown beside the mode on transit legs.
  final String? providerCode;
  final String? distanceKm;
  final int durationSeconds;
  final double? fareINR;

  /// Scheduled "HH:MM" at the boarding and alighting stops. Null on walking
  /// legs and on services whose operator publishes no timetable.
  final String? departureTime;
  final String? arrivalTime;

  /// Stops travelled on this leg — what a rider counts out of the window.
  /// Null on walking and hailed legs, which pass no stops.
  final int? stopCount;

  /// Minutes waiting at this leg's boarding stop. Null on walks.
  final int? waitMinutes;

  /// True when that wait is the generic estimate rather than a published gap.
  /// Shown differently, because an estimate read as a timetable is how someone
  /// misses the last service of the night.
  final bool waitIsEstimated;

  JourneyLegModel({
    required this.mode,
    required this.fromPlaceId,
    required this.toPlaceId,
    required this.fromName,
    required this.toName,
    this.routeId,
    this.routeCode,
    this.providerCode,
    this.distanceKm,
    this.fareINR,
    this.departureTime,
    this.arrivalTime,
    this.stopCount,
    this.waitMinutes,
    this.waitIsEstimated = false,
    required this.durationSeconds,
  });

  /// "Stay on for 7 stops" — null when the leg passes none.
  String? get stopsLabel {
    final count = stopCount;
    if (count == null || count <= 0) return null;
    return 'Stay on for $count ${count == 1 ? 'stop' : 'stops'}';
  }

  /// "Wait 4 min" / "No wait", or null when nothing is known.
  String? get waitLabel {
    final wait = waitMinutes;
    if (wait == null) return null;
    return wait == 0 ? 'Change straight over' : 'Wait $wait min';
  }

  bool get isWalk => mode.toUpperCase() == 'WALK';

  /// Lower-case key for RatrooTheme.modeColor and the icon map.
  String get modeKey {
    switch (mode.toUpperCase()) {
      case 'SUBURBAN_RAIL':
      case 'RAIL':
        return 'rail';
      case 'METRO':
        return 'metro';
      case 'FERRY':
        return 'ferry';
      case 'TRAM':
        return 'tram';
      case 'AUTO':
        return 'auto';
      case 'SHARED_AUTO':
        return 'shared_auto';
      case 'WALK':
        return 'walk';
      default:
        return 'bus';
    }
  }

  int get minutes => (durationSeconds / 60).round();

  String get durationLabel {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  /// "Walk 200 m" / "Walk 1.2 km", or just "Walk" when no distance is given.
  String get walkLabel {
    final km = double.tryParse(distanceKm ?? '');
    if (km == null || km <= 0) return 'Walk';
    return km < 1 ? 'Walk ${(km * 1000).round()} m' : 'Walk ${km.toStringAsFixed(1)} km';
  }

  factory JourneyLegModel.fromJson(Map<String, dynamic> json) {
    return JourneyLegModel(
      mode: json['mode'] ?? 'WALK',
      fromPlaceId: json['fromPlaceId'] ?? '',
      toPlaceId: json['toPlaceId'] ?? '',
      fromName: json['fromName'] ?? '',
      toName: json['toName'] ?? '',
      routeId: json['routeId'],
      // Backend calls it serviceName / providerCode.
      routeCode: json['routeCode'] ?? json['serviceName'],
      providerCode: json['providerCode'],
      distanceKm: json['distanceKm']?.toString(),
      fareINR: (json['fareINR'] as num?)?.toDouble(),
      departureTime: json['departureTime'] as String?,
      arrivalTime: json['arrivalTime'] as String?,
      durationSeconds: json['durationSeconds'] ??
          ((json['durationMinutes'] as num?)?.round() ?? 0) * 60,
      stopCount: (json['stopCount'] as num?)?.round(),
      waitMinutes: (json['waitMinutes'] as num?)?.round(),
      waitIsEstimated: json['waitIsEstimated'] == true,
    );
  }
}
