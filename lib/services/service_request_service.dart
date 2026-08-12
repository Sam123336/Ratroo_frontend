import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../providers/api_providers.dart';

/// Asking Ratroo to cover where you live.
///
/// Sent by riders in states we hold no data for. Deliberately unauthenticated:
/// the whole point is someone with no account, finding an empty app, leaving a
/// number. Requiring sign-up first would collect nothing.
class ServiceRequestService {
  final ApiClient _apiClient;

  const ServiceRequestService(this._apiClient);

  Future<ApiResponse<bool>> request({
    required String stateCode,
    required String phone,
    String? regionName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      await _apiClient.client.post('/service-requests', data: {
        'stateCode': stateCode,
        'phone': phone,
        'regionName': ?regionName,
        'latitude': ?latitude,
        'longitude': ?longitude,
      });
      return ApiResponse(success: true, data: true);
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    }
  }
}

final serviceRequestServiceProvider = Provider<ServiceRequestService>(
  (ref) => ServiceRequestService(ref.watch(apiClientProvider)),
);
