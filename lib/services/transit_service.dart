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
        (data) => (data as List).map((e) => RouteModel.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
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
      return ApiResponse(success: false, error: e.message);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
