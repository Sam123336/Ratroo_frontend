import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/api_client.dart';
import 'package:ratroo_app/models/journey.dart';
import 'package:ratroo_app/models/place.dart';
import 'package:ratroo_app/models/route.dart';

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

  test('Place reads departures from /v1/places/:id, verbatim from the API', () {
    final place = Place.fromJson({
      'id': '36d50636-6abf-44b5-8e75-b8cc25acbf3a',
      'title': 'Bankura Bus Stand',
      'category': 'STOP',
      'latitude': 23.2324,
      'longitude': 87.0753,
      'routes': [
        {'id': 'r1', 'name': 'WBBus service 135', 'providerCode': 'WBBUS'},
      ],
      'departures': [
        {
          'time': '01:40',
          'routeId': '019fe206-5bd9-76dc-8fcd-585d8b6d4046',
          'routeName': 'WBBus service 135',
          'timeSource': 'SCRAPED',
          'headsign': 'Tatanagar',
          'operator': 'ABIR SUPER',
          'vehicle': 'WB05C4556',
        },
        {
          'time': '14:05',
          'routeId': '019fe206-5bd9-7adb-9e9c-329b6f860193',
          'routeName': 'WBBus service 152',
          'timeSource': 'INTERPOLATED',
          'headsign': null,
        },
      ],
      'sources': [
        {'providerCode': 'WBBUS', 'name': 'WBBUS', 'website': null},
      ],
    });

    expect(place.routes.single.name, 'WBBus service 135');
    expect(place.departures.first.headsign, 'Tatanagar');
    // The name on the bus, which is how riders identify it at the stand.
    expect(place.departures.first.busLabel, 'ABIR SUPER · WB05C4556');
    // Most trips have no operator recorded; the row falls back to the route.
    expect(place.departures.last.busLabel, isNull);
    expect(place.departures.first.isEstimated, isFalse);
    expect(place.departures.last.isEstimated, isTrue);
    expect(place.sources.single.website, isNull);

    // The screen splits "upcoming" from "earlier" on this value.
    expect(place.departures.first.minutesOfDay, 100);
    expect(place.departures.last.minutesOfDay, 14 * 60 + 5);
  });

  test('Departure survives a malformed time instead of crashing the screen', () {
    expect(const Departure(time: '', routeId: 'r', routeName: 'n').minutesOfDay, isNull);
    expect(const Departure(time: 'noon', routeId: 'r', routeName: 'n').minutesOfDay, isNull);
  });

  test('Place with no departures parses to an empty list, not null', () {
    final place = Place.fromJson({'id': 'x', 'title': 'Quiet Stop'});
    expect(place.departures, isEmpty);
    expect(place.routes, isEmpty);
  });

  test('RouteModel titles a route by where it goes, never by the scraper slug', () {
    final route = RouteModel.fromJson({
      'id': '019fe206-5bd9-76dc-8fcd-585d8b6d4046',
      'longName': 'WBBus service 135',
      'routeCode': null,
      'providerCode': 'WBBUS',
      'providerWebsite': 'https://wbbus.in',
      'originName': 'Tatanagar',
      'destinationName': 'Baharampur',
      'externalId': 'wbbus:bus:carwan-wb55e9417-tatanagar-baharampur-1039:route',
      'stops': [
        {'name': 'Baharampur', 'stopSequence': 1, 'departureTime': '19:00', 'latitude': null, 'longitude': null},
        {'name': 'Kandi', 'stopSequence': 2, 'departureTime': '19:45', 'latitude': '23.95', 'longitude': '88.03'},
      ],
    });

    expect(route.title, 'Tatanagar \u2192 Baharampur');
    expect(route.title, isNot(contains('wbbus:bus:')));
    expect(route.stops.length, 2);
    expect(route.stops.first.departureTime, '19:00');
    // Postgres sends DECIMAL as a string; a silent null here empties the map.
    expect(route.stops.last.lat, 23.95);
    // One located stop is not a line worth drawing.
    expect(route.mappableStops, isEmpty);
  });

  test('RouteModel falls back to the operator name when an endpoint is missing', () {
    final route = RouteModel.fromJson({
      'id': 'r1',
      'longName': 'AANI: from Chittaranjan',
      'providerCode': 'WBBUS',
      'originName': 'Chittaranjan',
      'destinationName': null,
    });

    expect(route.title, 'AANI: from Chittaranjan');
    expect(route.providerWebsite, isNull);
  });

  test('elapsed minutes count from the origin, wrapping past midnight', () {
    final route = RouteModel.fromJson({
      'id': 'r1',
      'longName': 'Bandwan - Kolkata (Esplanade)',
      'providerCode': 'WBBUS',
      'stops': [
        {'name': 'Bandwan', 'stopSequence': 1, 'departureTime': '19:20'},
        {'name': 'Manbazar', 'stopSequence': 2, 'departureTime': '20:40'},
        {'name': 'No time here', 'stopSequence': 3, 'departureTime': null},
        // Overnight service: 00:20 is 5h after 19:20, not minus 19 hours.
        {'name': 'Kolkata (Esplanade)', 'stopSequence': 4, 'departureTime': '00:20'},
      ],
    });

    expect(route.elapsedMinutes, [0, 80, null, 300]);
  });

  test('elapsed minutes are all null when the origin has no time', () {
    final route = RouteModel.fromJson({
      'id': 'r2',
      'providerCode': 'WBTC',
      'stops': [
        {'name': 'A', 'stopSequence': 1, 'departureTime': null},
        {'name': 'B', 'stopSequence': 2, 'departureTime': '09:00'},
      ],
    });

    // Without a start there is nothing to measure from, so no number is shown.
    expect(route.elapsedMinutes, [null, null]);
  });
}
