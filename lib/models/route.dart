class RouteModel {
  final String id;
  final String routeCode;
  final String providerCode;
  final String originId;
  final String destinationId;
  final String originName;
  final String destinationName;
  final List<String> viaPoints;

  RouteModel({
    required this.id,
    required this.routeCode,
    required this.providerCode,
    required this.originId,
    required this.destinationId,
    required this.originName,
    required this.destinationName,
    this.viaPoints = const [],
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    return RouteModel(
      id: json['id'] ?? '',
      routeCode: json['routeCode'] ?? '',
      providerCode: json['providerCode'] ?? '',
      originId: json['originId'] ?? '',
      destinationId: json['destinationId'] ?? '',
      originName: json['originName'] ?? 'Unknown',
      destinationName: json['destinationName'] ?? 'Unknown',
      viaPoints: List<String>.from(json['viaPoints'] ?? []),
    );
  }
}
