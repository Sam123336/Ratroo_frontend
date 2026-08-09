import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../models/place.dart';

/// Stops found near a point, and how far we had to look to find them.
class NearbyResult {
  final List<Place> places;

  /// The radius that actually returned something, in metres.
  final int radiusMetres;

  /// True when the first, tightest search came back empty.
  final bool widened;

  const NearbyResult({
    required this.places,
    required this.radiusMetres,
    this.widened = false,
  });

  String get radiusLabel => radiusMetres < 1000
      ? '$radiusMetres m'
      : '${(radiusMetres / 1000).round()} km';
}

class NearbyService {
  final ApiClient _apiClient;

  NearbyService(this._apiClient);

  /// Widens the search until it finds something, then stops.
  ///
  /// A fixed 1 km is a city assumption. In rural West Bengal the nearest stop
  /// is routinely 10 km away, so "No nearby stations found" was really "we
  /// only looked one kilometre" — useless to exactly the users the app is for.
  static const _radii = [1000, 5000, 15000, 30000];

  Future<ApiResponse<NearbyResult>> findNearest(double lat, double lon) async {
    for (final radius in _radii) {
      final response = await getNearbyStops(lat, lon, radius: radius);
      if (!response.success) {
        return ApiResponse(success: false, error: response.error);
      }

      final places = response.data ?? const <Place>[];
      if (places.isNotEmpty) {
        return ApiResponse(
          success: true,
          data: NearbyResult(
            places: places,
            radiusMetres: radius,
            widened: radius != _radii.first,
          ),
        );
      }
    }

    // Genuinely nothing within 30 km — a real answer, not a failure.
    return ApiResponse(
      success: true,
      data: NearbyResult(places: const [], radiusMetres: _radii.last),
    );
  }

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
        (data) => asList(data).map((e) => Place.fromJson(e)).toList(),
      );
    } on DioException catch (e) {
      return ApiResponse(success: false, error: friendlyError(e));
    } catch (e) {
      return ApiResponse(success: false, error: e.toString());
    }
  }
}
