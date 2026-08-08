/// One scheduled departure from a stop.
class Departure {
  /// "HH:MM" as published by the operator.
  final String time;
  final String routeId;
  final String routeName;

  /// Where the service is headed — the last stop on its trip.
  final String? headsign;

  /// SCRAPED (published by the operator) or INTERPOLATED (estimated between
  /// two known times). Shown to the user, because an estimate is not a promise.
  final String? timeSource;

  const Departure({
    required this.time,
    required this.routeId,
    required this.routeName,
    this.headsign,
    this.timeSource,
  });

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
    this.distanceMetres,
    this.city,
    this.district,
    this.state,
  });

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
  String get readableType {
    switch (type) {
      case 'BUS_STOP':
      case 'STOP':
        return 'Bus stop';
      case 'FERRY_GHAT':
        return 'Ferry ghat';
      case 'METRO_STATION':
        return 'Metro station';
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
      distanceMetres: (json['distanceMeters'] as num?)?.toDouble(),
      city: json['city'] as String?,
      district: json['district'] as String?,
      state: json['state'] as String?,
    );
  }
}
