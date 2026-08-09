/// One stop along a route, in running order.
class RouteStop {
  final String name;
  final int sequence;

  /// Scheduled departure "HH:MM", or null where no timetable was published.
  final String? departureTime;
  final double? lat;
  final double? lon;

  const RouteStop({
    required this.name,
    required this.sequence,
    this.departureTime,
    this.lat,
    this.lon,
  });

  bool get hasPosition => lat != null && lon != null;

  /// Minutes since midnight, or null when no time is published.
  int? get minutesOfDay {
    final parts = (departureTime ?? '').split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    return (h == null || m == null) ? null : h * 60 + m;
  }

  factory RouteStop.fromJson(Map<String, dynamic> json) => RouteStop(
        name: json['name'] as String? ?? 'Unnamed stop',
        sequence: (json['stopSequence'] as num?)?.toInt() ?? 0,
        departureTime: json['departureTime'] as String?,
        // Postgres sends DECIMAL as a string over JSON.
        lat: _number(json['latitude']),
        lon: _number(json['longitude']),
      );

  static double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

class RouteModel {
  final String id;

  /// A synthetic code that repeats across unrelated routes — not a route
  /// number, so never shown as the title on its own.
  final String routeCode;
  final String providerCode;

  /// The operator's own site, or null when none is recorded.
  final String? providerWebsite;

  /// The best page the operator has for this route — its own timetable when
  /// there is one, otherwise the closest listing.
  final String? sourceUrl;

  /// What [sourceUrl] opens: 'route' (this route's own page), 'search' (every
  /// bus on this corridor, across operators), 'index' (the operator's route
  /// list) or 'site' (its front page).
  final String sourceKind;

  /// True when [sourceUrl] is the page for THIS route, not a route index.
  /// Only WBBUS publishes per-route pages; WBTC has one list of all routes,
  /// and the rest have nothing addressable.
  final bool sourceIsExact;

  /// The name painted on the bus, e.g. "APANJAN", and its registration.
  /// Only WBBUS and BUSSATHI record these; null everywhere else.
  final String? operator;
  final String? vehicle;

  /// The operator's own description, e.g. "JINIA: Bankura to Durgapur".
  final String longName;
  final String originId;
  final String destinationId;
  final String? originName;
  final String? destinationName;
  final List<RouteStop> stops;

  RouteModel({
    required this.id,
    required this.routeCode,
    required this.providerCode,
    this.providerWebsite,
    this.sourceUrl,
    this.sourceIsExact = false,
    this.sourceKind = 'site',
    this.operator,
    this.vehicle,
    this.longName = '',
    required this.originId,
    required this.destinationId,
    this.originName,
    this.destinationName,
    this.stops = const [],
  });

  /// What a rider calls this route. Falls back through the endpoints and the
  /// operator's description — never to the scraper's external id.
  String get title {
    if (originName != null && destinationName != null) {
      return '$originName → $destinationName';
    }
    if (longName.trim().isNotEmpty) return longName.trim();
    if (originName != null) return 'From $originName';
    return routeCode.isEmpty ? 'Route' : routeCode;
  }

  /// "APANJAN · WB67D5949", or null when the operator was never recorded.
  /// Where "see the source" should go: the route's own page on the operator's
  /// site when there is one, else its front page, else nowhere.
  String? get bestSourceUrl => sourceUrl ?? providerWebsite;

  String? get busLabel {
    final name = operator?.trim();
    if (name == null || name.isEmpty) return null;
    final reg = vehicle?.trim();
    return reg == null || reg.isEmpty ? name : '$name · $reg';
  }

  /// True when not one stop on this route has a published time, so the whole
  /// elapsed column would be dashes.
  bool get hasNoTimes => stops.every((s) => s.departureTime == null);

  /// Minutes from the first stop to each stop, or null where either end has no
  /// published time. Wraps midnight, since overnight services are common here.
  ///
  /// This is elapsed time along the route — "25 mins" against Pursurah means
  /// 25 minutes after boarding at the origin, which is what the reference
  /// board shows and what a rider actually wants.
  List<int?> get elapsedMinutes {
    final start = stops.isEmpty ? null : stops.first.minutesOfDay;
    if (start == null) return List.filled(stops.length, null);

    return stops.map((stop) {
      final at = stop.minutesOfDay;
      if (at == null) return null;
      final delta = at - start;
      return delta < 0 ? delta + 24 * 60 : delta;
    }).toList();
  }

  /// Points to draw, in order. Empty when too few stops are geolocated.
  List<RouteStop> get mappableStops {
    final located = stops.where((s) => s.hasPosition).toList();
    return located.length < 2 ? const [] : located;
  }

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'];

    return RouteModel(
      id: json['id'] ?? '',
      routeCode: json['routeCode'] ?? '',
      providerCode: json['providerCode'] ?? '',
      providerWebsite: json['providerWebsite'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      sourceIsExact: json['sourceIsExact'] == true,
      sourceKind: json['sourceKind'] as String? ?? 'site',
      operator: json['operator'] as String?,
      vehicle: json['vehicle'] as String?,
      longName: json['longName'] as String? ?? '',
      originId: json['originId'] ?? '',
      destinationId: json['destinationId'] ?? '',
      // Null means "not published", which the UI states rather than hiding
      // behind the word "Unknown".
      originName: json['originName'] as String?,
      destinationName: json['destinationName'] as String?,
      stops: rawStops is List
          ? rawStops
              .whereType<Map<String, dynamic>>()
              .map(RouteStop.fromJson)
              .toList()
          : const [],
    );
  }
}
