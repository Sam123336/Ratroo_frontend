import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/format.dart';
import 'package:ratroo_app/screens/home_screen.dart';

void main() {
  group('groupedNumber', () {
    test('separates thousands so a five-figure count is readable', () {
      expect(groupedNumber(11788), '11,788');
      expect(groupedNumber(2750), '2,750');
      expect(groupedNumber(1000000), '1,000,000');
    });

    test('leaves short numbers alone', () {
      expect(groupedNumber(0), '0');
      expect(groupedNumber(7), '7');
      expect(groupedNumber(999), '999');
    });
  });

  group('timeAgo', () {
    final now = DateTime(2026, 8, 11, 12, 0);

    test('reports the coarsest unit that is still true', () {
      expect(timeAgo(now.subtract(const Duration(seconds: 20)), now: now), 'just now');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(timeAgo(now.subtract(const Duration(hours: 1)), now: now), '1 hour ago');
      expect(timeAgo(now.subtract(const Duration(hours: 2)), now: now), '2 hours ago');
      expect(timeAgo(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
      expect(timeAgo(now.subtract(const Duration(days: 5)), now: now), '5 days ago');
      expect(timeAgo(now.subtract(const Duration(days: 60)), now: now), '2 months ago');
    });

    test('a server clock ahead of the device never reads as the future', () {
      expect(timeAgo(now.add(const Duration(minutes: 3)), now: now), 'just now');
    });
  });

  group('greeting', () {
    test('changes with the time of day', () {
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 6)), 'Good morning');
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 13)), 'Good afternoon');
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 21)), 'Good evening');
    });

    test('boundaries land on the right side', () {
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 11, 59)), 'Good morning');
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 12, 0)), 'Good afternoon');
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 16, 59)), 'Good afternoon');
      expect(HomeScreen.greeting(DateTime(2026, 8, 11, 17, 0)), 'Good evening');
    });
  });
}
