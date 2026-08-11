import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/location_service.dart';

void main() {
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
