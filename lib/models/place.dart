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
      // /v1/search speaks title/category/latitude/longitude.
      id: json['id'] ?? '',
      canonicalName:
          json['canonicalName'] ?? json['name'] ?? json['title'] ?? 'Unknown Place',
      type: json['type'] ?? json['category'],
      lat: ((json['lat'] ?? json['latitude']) as num?)?.toDouble(),
      lon: ((json['lon'] ?? json['longitude']) as num?)?.toDouble(),
    );
  }
}
