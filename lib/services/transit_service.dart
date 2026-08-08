import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/coverage_summary.dart';
import '../models/provider.dart';
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

  /// What we cover where the user is standing.
  ///
  /// The home screen used to announce "2800 routes ... across West Bengal" to
  /// everyone. Both the count and the region now come from the stops nearest
  /// the user, so someone in Bengaluru is told about Karnataka.
  Future<ApiResponse<CoverageSummary>> getCoverageSummary(double lat, double lng) async {
    try {
      final response = await _apiClient.client.get(
        '/coverage/summary',
        queryParameters: {'lat': lat, 'lng': lng},
      );

      // The interceptor wraps the controller's own { data: ... } envelope.
      final body = response.data['data'];
      final payload = (body is Map && body['data'] is Map) ? body['data'] : body;

      return ApiResponse(
        success: true,
        data: CoverageSummary.fromJson(Map<String, dynamic>.from(payload as Map)),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  /// Every operator in the data, busiest first.
  Future<ApiResponse<List<TransitProvider>>> getProviders() async {
    try {
      final response = await _apiClient.client.get('/coverage/providers');
      final body = response.data['data'];
      final list = (body is Map ? body['data'] : body) as List? ?? const [];

      return ApiResponse(
        success: true,
        data: list
            .whereType<Map<String, dynamic>>()
            .map(TransitProvider.fromJson)
            .toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse<TransitProvider>> getProvider(String code) async {
    try {
      final response = await _apiClient.client.get('/coverage/providers/$code');
      final body = response.data['data'];
      final payload = (body is Map && body['data'] is Map) ? body['data'] : body;

      return ApiResponse(
        success: true,
        data: TransitProvider.fromJson(Map<String, dynamic>.from(payload as Map)),
      );
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
