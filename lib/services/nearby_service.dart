import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/place.dart';

class NearbyService {
  final ApiClient _apiClient;

  NearbyService(this._apiClient);

  Future<ApiResponse<List<Place>>> getNearbyStops(double lat, double lon, {int radius = 1000}) async {
    try {
      final response = await _apiClient.client.get(
        '/stops/nearby',
        queryParameters: {
          'lat': lat,
          'lng': lon,
          'radius': radius,
        }
      );
      return ApiResponse.fromJson(
        response.data,
        (data) => (data as List).map((e) => Place.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: e.message);
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
