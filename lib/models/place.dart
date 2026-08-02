class Place {
  final String id;
  final String canonicalName;
  final String? type;
  final double? lat;
  final double? lon;

  Place({
    required this.id,
    required this.canonicalName,
    this.type,
    this.lat,
    this.lon,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'] ?? '',
      canonicalName: json['canonicalName'] ?? json['name'] ?? 'Unknown Place',
      type: json['type'],
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
    );
  }
}
