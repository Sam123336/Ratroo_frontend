import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/place.dart';

class SearchService {
  final ApiClient _apiClient;

  SearchService(this._apiClient);

  Future<ApiResponse<List<Place>>> searchPlaces(String query) async {
    try {
      final response = await _apiClient.client.get(
        '/search',
        queryParameters: {'q': query},
      );
      
      return ApiResponse.fromJson(
        response.data,
        (data) => (data as List).map((e) => Place.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: e.message ?? 'An error occurred during search',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }
}
