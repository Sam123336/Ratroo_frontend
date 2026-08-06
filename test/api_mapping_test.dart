import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/api_client.dart';
import 'package:ratroo_app/models/journey.dart';
import 'package:ratroo_app/models/place.dart';

/// Guards the app<->backend field mapping. Payloads below are verbatim from
/// the running API — if the backend renames a field, this fails instead of the
/// UI silently showing "Unknown Place" / "0 min".
void main() {
  test('Place reads the /v1/search shape (title, category, latitude)', () {
    final place = Place.fromJson({
      'id': '3422394b-3d4a-4f4f-a922-4a818da2ddb6',
      'category': 'BUS_STOP',
      'title': 'Howrah Maidan',
      'latitude': 22.5838585,
      'longitude': 88.3339983,
    });

    expect(place.canonicalName, 'Howrah Maidan');
    expect(place.type, 'BUS_STOP');
    expect(place.lat, closeTo(22.5838585, 1e-9));
    expect(place.lon, closeTo(88.3339983, 1e-9));
  });

  test('asList unwraps both envelope shapes', () {
    expect(asList([1, 2]), [1, 2]);
    expect(asList({'data': [1], 'total': 1, 'page': 1}), [1]); // /v1/routes
    expect(asList({'data': [], 'count': 0}), []); // /v1/stops/nearby
    expect(asList(null), []);
  });

  test('JourneyPlan converts backend minutes to seconds', () {
    final plan = JourneyPlanModel.fromJson({
      'totalDurationMinutes': 32,
      'legs': [
        {'mode': 'BUS', 'durationMinutes': 6, 'serviceName': 'S-12', 'fromName': 'A', 'toName': 'B'},
      ],
    });

    expect(plan.totalDurationSeconds, 32 * 60);
    expect(plan.legs.single.durationSeconds, 6 * 60);
    expect(plan.legs.single.routeCode, 'S-12');
  });

  test('friendlyError never leaks the Dio essay', () {
    final req = RequestOptions(path: '/journey');

    expect(
      friendlyError(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 404,
          data: {'message': "Destination 'Sector V' was not found."},
        ),
      )),
      "Destination 'Sector V' was not found.",
    );

    expect(
      friendlyError(DioException(requestOptions: req, type: DioExceptionType.connectionError)),
      "Can't reach Ratroo. Check your connection.",
    );
  });
}
