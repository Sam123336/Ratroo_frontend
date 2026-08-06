class JourneyPlanModel {
  final List<JourneyLegModel> legs;
  final int totalDurationSeconds;
  final double totalFare;

  JourneyPlanModel({
    required this.legs,
    required this.totalDurationSeconds,
    required this.totalFare,
  });

  // Backend (JourneyResponseDto) speaks minutes; this model speaks seconds.
  factory JourneyPlanModel.fromJson(Map<String, dynamic> json) {
    return JourneyPlanModel(
      legs: (json['legs'] as List?)?.map((e) => JourneyLegModel.fromJson(e)).toList() ?? [],
      totalDurationSeconds: json['totalDurationSeconds'] ??
          ((json['totalDurationMinutes'] as num?)?.round() ?? 0) * 60,
      totalFare: (json['totalFare'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class JourneyLegModel {
  final String mode; // BUS, FERRY, METRO, WALK
  final String fromPlaceId;
  final String toPlaceId;
  final String fromName;
  final String toName;
  final String? routeId;
  final String? routeCode;
  final int durationSeconds;

  JourneyLegModel({
    required this.mode,
    required this.fromPlaceId,
    required this.toPlaceId,
    required this.fromName,
    required this.toName,
    this.routeId,
    this.routeCode,
    required this.durationSeconds,
  });

  factory JourneyLegModel.fromJson(Map<String, dynamic> json) {
    return JourneyLegModel(
      mode: json['mode'] ?? 'WALK',
      fromPlaceId: json['fromPlaceId'] ?? '',
      toPlaceId: json['toPlaceId'] ?? '',
      fromName: json['fromName'] ?? '',
      toName: json['toName'] ?? '',
      routeId: json['routeId'],
      // Backend calls it serviceName / providerCode.
      routeCode: json['routeCode'] ?? json['serviceName'] ?? json['providerCode'],
      durationSeconds: json['durationSeconds'] ??
          ((json['durationMinutes'] as num?)?.round() ?? 0) * 60,
    );
  }
}
