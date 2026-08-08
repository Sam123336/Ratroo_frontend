import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/api_client.dart';
import 'package:ratroo_app/core/location_service.dart';
import 'package:ratroo_app/models/place.dart';
import 'package:ratroo_app/providers/api_providers.dart';
import 'package:ratroo_app/screens/place_details_screen.dart';

/// The Place Details screen used to lead with a "Connectivity Index" and a
/// hardcoded "96% Reliability". These guard what replaced them: real
/// departures, honest empty states, and no invented numbers.
void main() {
  /// Fixed at 08:00 so "next departure" is the same on every run.
  Widget harness(Place place, {DateTime? now}) {
    return ProviderScope(
      overrides: [
        nowProvider.overrideWithValue(() => now ?? DateTime(2026, 8, 9, 8, 0)),
        placeDetailsProvider.overrideWith(
          (ref, id) async => ApiResponse(success: true, data: place),
        ),
        // A refused permission must not hide the departures.
        userLocationProvider.overrideWith((ref) async => UserLocation.fallback),
      ],
      child: const MaterialApp(home: PlaceDetailsScreen(placeId: 'stop-1')),
    );
  }

  Place placeWith(List<Departure> departures, {List<PlaceRoute> routes = const []}) => Place(
        id: 'stop-1',
        canonicalName: 'Bankura Bus Stand',
        type: 'BUS_STOP',
        lat: 23.2324,
        lon: 87.0753,
        routes: routes,
        departures: departures,
        sources: const [PlaceSource(providerCode: 'WBBUS', name: 'WBBUS')],
      );

  testWidgets('shows departure times, destinations and the operator', (tester) async {
    await tester.pumpWidget(harness(placeWith(const [
      Departure(
        time: '23:55',
        routeId: 'r1',
        routeName: 'WBBus service 135',
        headsign: 'Tatanagar',
        timeSource: 'SCRAPED',
      ),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('23:55'), findsOneWidget);
    expect(find.text('To Tatanagar'), findsOneWidget);
    expect(find.text('WBBus service 135'), findsOneWidget);
    expect(find.text('Data from WBBUS.'), findsOneWidget);

    // The metrics that meant nothing to a rider are gone for good.
    expect(find.textContaining('Connectivity Index'), findsNothing);
    expect(find.textContaining('Reliability'), findsNothing);
    expect(find.textContaining('Geo Located'), findsNothing);
  });

  testWidgets('marks an interpolated time as estimated rather than passing it off', (tester) async {
    await tester.pumpWidget(harness(placeWith(const [
      Departure(
        time: '23:50',
        routeId: 'r2',
        routeName: 'WBBus service 152',
        headsign: 'Purulia',
        timeSource: 'INTERPOLATED',
      ),
    ])));
    await tester.pumpAndSettle();

    expect(find.textContaining('estimated time'), findsOneWidget);
  });

  testWidgets('says plainly when no timetable exists instead of showing an empty list',
      (tester) async {
    await tester.pumpWidget(harness(placeWith(
      const [],
      routes: const [PlaceRoute(id: 'r1', name: 'Airport to Nabanna', providerCode: 'WBTC')],
    )));
    await tester.pumpAndSettle();

    expect(find.textContaining('No timetable has been published'), findsOneWidget);
    // The routes still stop there — that fact survives the missing times.
    expect(find.text('Airport to Nabanna'), findsOneWidget);
  });

  testWidgets('a stop with nothing scheduled left today points at tomorrow', (tester) async {
    await tester.pumpWidget(harness(placeWith(const [
      Departure(time: '00:01', routeId: 'r3', routeName: 'Night service', headsign: 'Digha'),
    ])));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tomorrow starts at 00:01'), findsOneWidget);
  });

  testWidgets('counts down a departure that is minutes away', (tester) async {
    await tester.pumpWidget(harness(placeWith(const [
      Departure(time: '08:12', routeId: 'r4', routeName: 'WBBus service 9', headsign: 'Digha'),
    ])));
    await tester.pumpAndSettle();

    expect(find.text('in 12 min'), findsOneWidget);
  });
}
