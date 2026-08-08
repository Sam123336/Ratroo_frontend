import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/route.dart';

class TransitService {
  final ApiClient _apiClient;

  TransitService(this._apiClient);

  Future<ApiResponse<List<RouteModel>>> getRoutes() async {
    try {
      final response = await _apiClient.client.get('/routes');
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

  /// How many routes are in the graph. Asks for one row and reads the total,
  /// so the home screen can state real coverage instead of a fixed percentage.
  Future<ApiResponse<int>> getRouteCount() async {
    try {
      final response = await _apiClient.client.get('/routes', queryParameters: {'limit': 1});
      final body = response.data;
      final total = body is Map ? (body['data']?['total'] ?? body['total']) as num? : null;

      return total == null
          ? ApiResponse(success: false, error: 'No route total in response')
          : ApiResponse(success: true, data: total.toInt());
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse<RouteModel>> getRouteDetails(String id) async {
    try {
      final response = await _apiClient.client.get('/routes/$id');
      return ApiResponse.fromJson(
        response.data,
        (data) => RouteModel.fromJson(data),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
