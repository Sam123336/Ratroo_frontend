import '../core/format.dart';

/// One scheduled departure from a stop.
class Departure {
  /// "HH:MM" as published by the operator.
  final String time;
  final String routeId;
  final String routeName;

  /// Where the service is headed — the last stop on its trip.
  final String? headsign;

  /// The name painted on the bus, e.g. "APANJAN" — how West Bengal's private
  /// services are actually identified at the stand. Null when unrecorded,
  /// which is most of them.
  final String? operator;

  /// Its registration, e.g. "WB67D5949".
  final String? vehicle;

  /// SCRAPED (published by the operator) or INTERPOLATED (estimated between
  /// two known times). Shown to the user, because an estimate is not a promise.
  final String? timeSource;

  const Departure({
    required this.time,
    required this.routeId,
    required this.routeName,
    this.headsign,
    this.operator,
    this.vehicle,
    this.timeSource,
  });

  /// "APANJAN · WB67D5949", or null when the operator was never recorded.
  String? get busLabel {
    final name = operator?.trim();
    if (name == null || name.isEmpty) return null;
    final reg = vehicle?.trim();
    return reg == null || reg.isEmpty ? name : '$name · $reg';
  }

  bool get isEstimated => timeSource == 'INTERPOLATED';

  /// Minutes since midnight, or null if the API sent something unparseable.
  int? get minutesOfDay {
    final parts = time.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  factory Departure.fromJson(Map<String, dynamic> json) {
    return Departure(
      time: json['time'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      routeName: json['routeName'] as String? ?? 'Unnamed service',
      headsign: json['headsign'] as String?,
      operator: json['operator'] as String?,
      vehicle: json['vehicle'] as String?,
      timeSource: json['timeSource'] as String?,
    );
  }
}

/// A service calling at a place.
class PlaceRoute {
  final String id;
  final String name;
  final String providerCode;

  const PlaceRoute({required this.id, required this.name, required this.providerCode});

  /// A label short enough for a chip in a list row.
  ///
  /// Most names are one of two shapes: "WBBus service 135", where the number
  /// is the only part a rider uses, or "KOLKATA to DIGHA", where the other end
  /// is. Anything else is shown as-is and ellipsised.
  ///
  /// [at] is the stop the row belongs to. Without it, "Bishnupur - Kolkata"
  /// listed at the Kolkata stop labelled itself "Kolkata" — telling a rider
  /// standing there that the bus goes where they already are.
  String shortLabelAt([String? at]) {
    final service = RegExp(r'(?:service|route)\s+([A-Za-z0-9/\-]+)\s*$', caseSensitive: false)
        .firstMatch(name);
    if (service != null) return service.group(1)!;

    final parts = name.split(RegExp(r'\s+(?:to|-|–|→)\s+')).map((p) => p.trim()).toList();
    if (parts.length != 2 || parts.any((p) => p.isEmpty)) return name;

    String key(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final here = at == null ? null : key(at);

    // The end that is not this stop. Falls back to the destination when the
    // row has no stop name or neither end matches it.
    if (here != null && key(parts.first) == here) return parts.last;
    if (here != null && key(parts.last) == here) return parts.first;
    return parts.last;
  }

  factory PlaceRoute.fromJson(Map<String, dynamic> json) => PlaceRoute(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Unnamed route',
        providerCode: json['providerCode'] as String? ?? '',
      );
}

/// The operator behind the data, and its official site when we have one.
class PlaceSource {
  final String providerCode;
  final String name;
  final String? website;

  const PlaceSource({required this.providerCode, required this.name, this.website});

  factory PlaceSource.fromJson(Map<String, dynamic> json) => PlaceSource(
        providerCode: json['providerCode'] as String? ?? '',
        name: json['name'] as String? ?? '',
        website: json['website'] as String?,
      );
}

class Place {
  final String id;
  final String canonicalName;
  final String? type;
  final double? lat;
  final double? lon;
  final List<PlaceRoute> routes;
  final List<Departure> departures;
  final List<PlaceSource> sources;

  /// The operator's timetable page for this stop, when it publishes one.
  final String? sourceUrl;

  /// Straight-line metres from the search centre. Only /v1/stops/nearby sends
  /// this; null everywhere else.
  final double? distanceMetres;

  /// Where the stop sits administratively. Sparsely filled — many stops carry
  /// only a state — so callers fall back through city → district → state.
  final String? city;
  final String? district;
  final String? state;

  Place({
    required this.id,
    required this.canonicalName,
    this.type,
    this.lat,
    this.lon,
    this.routes = const [],
    this.departures = const [],
    this.sources = const [],
    this.sourceUrl,
    this.distanceMetres,
    this.city,
    this.district,
    this.state,
  });

  /// [canonicalName] as a rider should read it: "KOLKATA" becomes "Kolkata",
  /// while "C.R.Ave" and "BB Ganguly St." survive untouched.
  ///
  /// A getter on the model rather than a `titleCaseName(...)` at each call
  /// site. Search already wrapped its rows and no other screen did, so the
  /// same stop was "Chandrakona Road" in one list and "CHANDRAKONA ROAD" in
  /// the next. Every screen that shows a name to a person reads this;
  /// [canonicalName] stays raw for the things that must match the API — query
  /// strings, deep links and the WBBUS timetable URL.
  String get displayName => titleCaseName(canonicalName);

  /// The area to name in "Where to, ___?".
  ///
  /// City first, then district. `state` is deliberately not a fallback: it is
  /// stored as a code, and "Where to, WB?" is worse than asking "Where to?".
  String? get areaName {
    for (final value in [city, district]) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  /// The stored enum spelled for a person. The UI used to print BUS_STOP.
  ///
  /// /v1/stops/nearby builds the category as `<routeType>_STOP`, so the live
  /// values are BUS_STOP, RAIL_STOP, FERRY_STOP and TRAM_STOP. Those were all
  /// falling through to "Transit stop" — a tram stop read as generic.
  String get readableType {
    switch (type) {
      case 'BUS_STOP':
        return 'Bus stop';
      // The generic type stored on places. It used to be read as "Bus stop",
      // which labelled tram stops and ferry ghats as buses.
      case 'STOP':
        return 'Transit stop';
      case 'FERRY_STOP':
      case 'FERRY_GHAT':
        return 'Ferry ghat';
      case 'TRAM_STOP':
        return 'Tram stop';
      case 'METRO_STOP':
      case 'METRO_STATION':
        return 'Metro station';
      case 'RAIL_STOP':
      case 'RAIL_STATION':
        return 'Railway station';
      default:
        return 'Transit stop';
    }
  }

  /// "420 m" / "3.4 km", or null when we have no distance to state.
  String? get distanceLabel {
    final metres = distanceMetres;
    if (metres == null) return null;
    return metres < 1000 ? '${metres.round()} m' : '${(metres / 1000).toStringAsFixed(1)} km';
  }

  static List<T> _list<T>(dynamic raw, T Function(Map<String, dynamic>) parse) {
    if (raw is! List) return const [];
    return raw.whereType<Map<String, dynamic>>().map(parse).toList();
  }

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      // /v1/search speaks title/category/latitude/longitude.
      id: json['id'] ?? '',
      canonicalName:
          json['canonicalName'] ?? json['name'] ?? json['title'] ?? 'Unknown Place',
      type: json['type'] ?? json['category'],
      lat: ((json['lat'] ?? json['latitude']) as num?)?.toDouble(),
      lon: ((json['lon'] ?? json['longitude']) as num?)?.toDouble(),
      routes: _list(json['routes'], PlaceRoute.fromJson),
      departures: _list(json['departures'], Departure.fromJson),
      sources: _list(json['sources'], PlaceSource.fromJson),
      sourceUrl: json['sourceUrl'] as String?,
      distanceMetres: (json['distanceMeters'] as num?)?.toDouble(),
      city: json['city'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
    );
  }
}
