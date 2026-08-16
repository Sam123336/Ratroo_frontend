import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/location_service.dart';

void main() {
  _debugOverrideGate();

  group('canReuse', () {
    test('a real fix is reused briefly, then re-asked', () {
      expect(canReuse(isLive: true, age: const Duration(seconds: 30)), isTrue);
      expect(canReuse(isLive: true, age: const Duration(minutes: 3)), isFalse);
    });

    test('a failure is reused too, so Retry attempts once and not twice', () {
      // Uncached failures made every rebuild wait out the 12s timeout again;
      // one Retry cost that twice and read as a dead button.
      expect(canReuse(isLive: false, age: const Duration(seconds: 5)), isTrue);
    });

    test('a failure expires far sooner than a fix', () {
      // A rider who turns location on should not wait two minutes for the app
      // to notice.
      expect(canReuse(isLive: false, age: const Duration(seconds: 45)), isFalse);
      expect(canReuse(isLive: true, age: const Duration(seconds: 45)), isTrue);
      expect(
        LocationService.failureCacheFor,
        lessThan(LocationService.cacheFor),
      );
    });
  });
}

/// The debug pin must never survive into a release build.
///
/// It is gated on `kDebugMode`, which is a compile-time constant — so this
/// asserts the gate is written in a form the compiler can eliminate, rather
/// than a runtime flag someone could flip.
void _debugOverrideGate() {
  test('the coordinate override is compiled out of release builds', () {
    final source = File('lib/core/location_service.dart').readAsStringSync();
    final override = source.substring(source.indexOf('UserLocation? get _debugOverride'));

    // kDebugMode must be the first thing checked, and negated, so the whole
    // body is dead code under `flutter build --release`.
    expect(override, contains('if (!kDebugMode'));
    expect(
      source.indexOf('kDebugMode'),
      lessThan(source.indexOf('_debugLat.isEmpty')),
      reason: 'kDebugMode must gate the override before the defines are read',
    );
  });
}
