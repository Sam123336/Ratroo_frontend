import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/models/coverage_summary.dart';

/// The home screen used to announce "Bus, metro, rail and ferry across West
/// Bengal" to everyone. Payloads below are verbatim from /v1/coverage/summary.
void main() {
  test('reads the Karnataka payload a Bengaluru user gets', () {
    final coverage = CoverageSummary.fromJson({
      'stateCode': 'KA',
      'region': 'Karnataka',
      'routeCount': 50,
      'modes': ['bus'],
    });

    expect(coverage.region, 'Karnataka');
    expect(coverage.routeCount, 50);
    expect(coverage.hasCoverage, isTrue);
    // One mode gets no list punctuation.
    expect(coverage.modesSentence, 'Bus');
  });

  test('reads the West Bengal payload, which has no metro', () {
    final coverage = CoverageSummary.fromJson({
      'stateCode': 'WB',
      'region': 'West Bengal',
      'routeCount': 2750,
      'modes': ['bus', 'ferry', 'rail', 'tram'],
    });

    expect(coverage.modesSentence, 'Bus, ferry, rail and tram');
    // The old copy claimed metro. No metro route exists in the data.
    expect(coverage.modesSentence, isNot(contains('metro')));
  });

  test('two modes read as "A and B", not "A, and B"', () {
    final coverage = CoverageSummary.fromJson({
      'region': 'Somewhere',
      'routeCount': 3,
      'modes': ['bus', 'ferry'],
    });

    expect(coverage.modesSentence, 'Bus and ferry');
  });

  test('a region with no routes is not presented as coverage', () {
    final coverage = CoverageSummary.fromJson({
      'stateCode': null,
      'region': null,
      'routeCount': 0,
      'modes': <String>[],
    });

    expect(coverage.hasCoverage, isFalse);
    expect(coverage.modesSentence, isEmpty);
  });

  test('a missing modes field does not crash the header', () {
    final coverage = CoverageSummary.fromJson({'region': 'Karnataka', 'routeCount': 50});
    expect(coverage.modes, isEmpty);
    expect(coverage.hasCoverage, isTrue);
  });
}
