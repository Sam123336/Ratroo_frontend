import 'package:dio/dio.dart';
import '../core/api_client.dart';

class AnalyticsService {
  final ApiClient _apiClient;

  AnalyticsService(this._apiClient);

  Future<ApiResponse<Map<String, dynamic>>> getPopularityMetrics() async {
    try {
      final response = await _apiClient.client.get('/analytics');
      return ApiResponse.fromJson(
        response.data,
        (data) => data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
