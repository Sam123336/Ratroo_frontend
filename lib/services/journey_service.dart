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
        },
        // Planning is a round-based search over 11,000 stops, and the first
        // call after a restart also pays a 6-second graph load. The 10-second
        // default timed it out and reported "the server took too long" for a
        // request that was still working.
        options: Options(receiveTimeout: const Duration(seconds: 45)),
      );
      return ApiResponse.fromJson(
        response.data,
        // /v1/journey returns the recommended plan as the object itself, with
        // the other ways to make the trip under `alternatives`.
        (data) {
          if (data is List) {
            return data.map((e) => JourneyPlanModel.fromJson(e)).toList();
          }

          final best = data as Map<String, dynamic>;
          final alternatives = best['alternatives'];

          return [
            JourneyPlanModel.fromJson(best),
            if (alternatives is List)
              ...alternatives
                  .whereType<Map<String, dynamic>>()
                  .map(JourneyPlanModel.fromJson),
          ];
        },
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
