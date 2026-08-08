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
