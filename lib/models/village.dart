class VillageModel {
  final String id;
  final String name;
  final String district;
  final bool hasDirectBus;
  final double distanceToNearestStopKm;
  final String? nearestStopName;

  VillageModel({
    required this.id,
    required this.name,
    required this.district,
    required this.hasDirectBus,
    required this.distanceToNearestStopKm,
    this.nearestStopName,
  });

  factory VillageModel.fromJson(Map<String, dynamic> json) {
    return VillageModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      district: json['district'] ?? '',
      hasDirectBus: json['hasDirectBus'] ?? false,
      distanceToNearestStopKm: (json['distanceToNearestStopKm'] as num?)?.toDouble() ?? 0.0,
      nearestStopName: json['nearestStopName'],
    );
  }
}
