import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/place.dart';

class SearchService {
  final ApiClient _apiClient;

  SearchService(this._apiClient);

  /// Detail for one place by id. Place Details used to pass the id into
  /// [searchPlaces], i.e. search for a UUID by name, which never matched.
  Future<ApiResponse<Place>> getPlaceById(String id) async {
    try {
      final response = await _apiClient.client.get('/places/$id');
      return ApiResponse.fromJson(response.data, (data) => Place.fromJson(data));
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }

  Future<ApiResponse<List<Place>>> searchPlaces(String query) async {
    try {
      final response = await _apiClient.client.get(
        '/search',
        queryParameters: {'q': query},
      );
      
      return ApiResponse.fromJson(
        response.data,
        (data) => asList(data).map((e) => Place.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: friendlyError(e),
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        error: e.toString(),
      );
    }
  }
}
