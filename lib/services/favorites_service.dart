import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/route.dart';

class FavoritesService {
  final ApiClient _apiClient;

  FavoritesService(this._apiClient);

  Future<ApiResponse<List<RouteModel>>> getFavorites() async {
    try {
      final response = await _apiClient.client.get('/favorites');
      return ApiResponse.fromJson(
        response.data,
        (data) => asList(data).map((e) => RouteModel.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse<bool>> addFavorite(String routeId) async {
    try {
      final response = await _apiClient.client.post('/favorites', data: {'routeId': routeId});
      return ApiResponse.fromJson(
        response.data,
        (data) => true,
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
