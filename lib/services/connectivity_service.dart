import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/village.dart';

class ConnectivityService {
  final ApiClient _apiClient;

  ConnectivityService(this._apiClient);

  Future<ApiResponse<List<VillageModel>>> getVillages(String query) async {
    try {
      final response = await _apiClient.client.get(
        '/villages',
        queryParameters: {'q': query},
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => asList(data).map((e) => VillageModel.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
