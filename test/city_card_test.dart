import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/models/coverage_summary.dart';
import 'package:ratroo_app/widgets/city_card.dart';
import 'package:ratroo_app/widgets/spot_carousel.dart';

const _wb = CoverageSummary(
  region: 'West Bengal',
  stateCode: 'WB',
  routeCount: 2750,
  stopCount: 2288,
  modes: ['bus', 'ferry', 'rail', 'tram'],
  byMode: [
    ModeCoverage(mode: 'ferry', routeCount: 9, stopCount: 18),
    ModeCoverage(mode: 'bus', routeCount: 2727, stopCount: 2150),
    ModeCoverage(mode: 'metro', routeCount: 0, stopCount: 0),
    ModeCoverage(mode: 'tram', routeCount: 6, stopCount: 20),
  ],
);

Future<void> _pump(WidgetTester tester, {String? city}) => tester.pumpWidget(
  ProviderScope(
    overrides: [
      travelSpotsProvider.overrideWith((ref, mode) async => <TravelSpot>[]),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CityCard(city: city, coverage: _wb),
      ),
    ),
  ),
);

void main() {
  testWidgets('names the city when one is known', (tester) async {
    await _pump(tester, city: 'Kolkata');
    expect(find.text('Travel across Kolkata'), findsOneWidget);
  });

  testWidgets('falls back to the region rather than guessing a city', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Travel across West Bengal'), findsOneWidget);
  });

  testWidgets('lists the busiest mode first', (tester) async {
    await _pump(tester, city: 'Kolkata');

    // Left to right now the modes are a horizontal strip, not a list.
    final bus = tester.getTopLeft(find.text('Bus')).dx;
    final ferry = tester.getTopLeft(find.text('Ferry')).dx;
    final tram = tester.getTopLeft(find.text('Tram')).dx;

    // 2,727 → 9 → 6, not alphabetical.
    expect(bus, lessThan(ferry));
    expect(ferry, lessThan(tram));
  });

  testWidgets('a mode with no routes is left out, not shown as zero', (
    tester,
  ) async {
    await _pump(tester, city: 'Kolkata');

    // An empty row reads as a broken network rather than missing data.
    expect(find.text('Metro'), findsNothing);
    expect(find.text('0 routes'), findsNothing);
  });

  testWidgets('uses the words riders use for each mode stop', (tester) async {
    await _pump(tester, city: 'Kolkata');

    expect(find.textContaining('18 ghats'), findsOneWidget);
    expect(find.textContaining('2,150 stops'), findsOneWidget);
  });

  _cityTree();
}

// Appended: the city tree.
const _kolkata = CoverageSummary(
  region: 'West Bengal',
  stateCode: 'WB',
  routeCount: 2750,
  stopCount: 2288,
  modes: ['bus', 'ferry', 'rail', 'tram'],
  byMode: [
    ModeCoverage(mode: 'bus', routeCount: 2727, stopCount: 2150),
    ModeCoverage(mode: 'tram', routeCount: 6, stopCount: 20),
  ],
  byCity: [
    CityCoverage(
      city: 'Kolkata',
      routeCount: 816,
      byMode: [
        ModeCoverage(mode: 'bus', routeCount: 803, stopCount: 900),
        ModeCoverage(mode: 'tram', routeCount: 1, stopCount: 4),
      ],
    ),
  ],
);

void _cityTree() {
  testWidgets('counts are the rider city when we hold it', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          travelSpotsProvider.overrideWith((ref, mode) async => <TravelSpot>[]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CityCard(city: 'Kolkata', coverage: _kolkata),
          ),
        ),
      ),
    );

    // 803 here, not the 2,727 state-wide — a tram runs in Kolkata and nowhere
    // else, so state totals would tell Bardhaman it has trams.
    expect(find.textContaining('803 routes'), findsOneWidget);
    expect(find.textContaining('2,727 routes'), findsNothing);
  });

  testWidgets('falls back to the state where the city is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          travelSpotsProvider.overrideWith((ref, mode) async => <TravelSpot>[]),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CityCard(city: 'Bardhaman', coverage: _kolkata),
          ),
        ),
      ),
    );

    // Bardhaman has no city row, so the state totals stand rather than
    // borrowing Kolkata's.
    expect(find.textContaining('2,727 routes'), findsOneWidget);
  });
}
