import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/location_service.dart';
import 'package:ratroo_app/models/place.dart';
import 'package:ratroo_app/providers/api_providers.dart';

/// The home header used to greet everyone with "Where to, Kolkata?", including
/// a user standing in Bengaluru. The city is now read off the nearest stops.
/// Payloads below are verbatim from /v1/stops/nearby.
void main() {
  Place fromNearby(Map<String, dynamic> json) => Place.fromJson(json);

  test('names Bengaluru from a BMTC stop', () {
    final place = fromNearby({
      'id': 'b1',
      'name': 'KR Market (Kalasipalya) - Platform Main Jn.',
      'city': 'Bengaluru',
      'district': 'Bengaluru Urban',
      'state': 'KA',
      'provider': 'BMTC_OFFICIAL',
      'distanceMeters': 268,
    });

    expect(place.areaName, 'Bengaluru');
    expect(place.distanceLabel, '268 m');
  });

  test('falls back to district when no city is recorded', () {
    final place = fromNearby({
      'id': 'b2',
      'name': 'Somewhere',
      'city': null,
      'district': 'Bankura',
      'state': 'WB',
    });

    expect(place.areaName, 'Bankura');
  });

  test('never falls back to the state code', () {
    // Most West Bengal stops carry only "WB" — "Where to, WB?" is worse than
    // asking "Where to?", so the header shows no city at all.
    final place = fromNearby({
      'id': 'b3',
      'name': 'BB Ganguly Xing',
      'city': null,
      'district': null,
      'state': 'WB',
    });

    expect(place.areaName, isNull);
  });

  test('treats blank strings as missing', () {
    expect(fromNearby({'id': 'b4', 'city': '   ', 'district': 'Hooghly'}).areaName, 'Hooghly');
  });

  test('drift threshold is crossed by a real move, not by standing still', () {
    // Kolkata centre to BB Ganguly Xing: same neighbourhood, no prompt.
    expect(distanceMetres(22.5726459, 88.3638953, 22.5691095, 88.3621602), lessThan(1500));

    // Kolkata to Bengaluru: unmistakably a different city.
    expect(distanceMetres(22.5726459, 88.3638953, 12.962895, 77.577538), greaterThan(1500));
  });

  group('driftedTo', () {
    const kolkata = UserLocation(
        latitude: 22.5726459, longitude: 88.3638953, status: LocationStatus.live);
    const bengaluru = UserLocation(
        latitude: 12.962895, longitude: 77.577538, status: LocationStatus.live);
    const bbGanguly = UserLocation(
        latitude: 22.5691095, longitude: 88.3621602, status: LocationStatus.live);

    test('prompts when the device has moved to another city', () {
      expect(driftedTo(kolkata, bengaluru), bengaluru);
    });

    test('stays quiet for a walk down the road', () {
      expect(driftedTo(kolkata, bbGanguly), isNull);
    });

    test('stays quiet when either position is a fallback', () {
      // Prompting "you have moved" off the Kolkata default would be a lie:
      // the fallback never described where the user actually was.
      expect(driftedTo(UserLocation.fallback, bengaluru), isNull);
      expect(driftedTo(kolkata, UserLocation.fallback), isNull);
    });

    test('stays quiet before any location is known', () {
      expect(driftedTo(null, bengaluru), isNull);
    });
  });
}
