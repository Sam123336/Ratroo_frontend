import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/journey.dart';

class JourneyService {
  final ApiClient _apiClient;

  JourneyService(this._apiClient);

  Future<ApiResponse<List<JourneyPlanModel>>> getJourneyPlan(String fromPlaceId, String toPlaceId) async {
    try {
      final response = await _apiClient.client.post(
        '/journey',
        data: {
          'from': fromPlaceId,
          'to': toPlaceId,
        }
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => (data as List).map((e) => JourneyPlanModel.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
