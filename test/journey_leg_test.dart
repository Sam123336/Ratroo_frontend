import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/models/journey.dart';

/// The journey leg fields the planner added: the mode a rider actually boards,
/// the stops they count on board, and how long they wait before it.
void main() {
  JourneyLegModel leg(Map<String, dynamic> overrides) => JourneyLegModel.fromJson({
        'mode': 'BUS',
        'fromName': 'A',
        'toName': 'B',
        'durationMinutes': 9,
        ...overrides,
      });

  group('mode', () {
    test('keeps a registered auto service distinct from a bus', () {
      // The backend stopped flattening AUTO and SHARED_AUTO into BUS. The app
      // had no case for either, so `default` sent them back to a bus icon and
      // bus colour — undoing the fix at the very last step.
      expect(leg({'mode': 'AUTO'}).modeKey, 'auto');
      expect(leg({'mode': 'SHARED_AUTO'}).modeKey, 'shared_auto');
    });

    test('still maps the modes it already knew', () {
      expect(leg({'mode': 'METRO'}).modeKey, 'metro');
      expect(leg({'mode': 'SUBURBAN_RAIL'}).modeKey, 'rail');
      expect(leg({'mode': 'TRAM'}).modeKey, 'tram');
      expect(leg({'mode': 'WALK'}).modeKey, 'walk');
    });

    test('falls back to bus only for a mode it has never seen', () {
      expect(leg({'mode': 'MONORAIL'}).modeKey, 'bus');
    });
  });

  group('stops on board', () {
    test('counts them for a boarded service', () {
      expect(leg({'stopCount': 7}).stopsLabel, 'Stay on for 7 stops');
      expect(leg({'stopCount': 1}).stopsLabel, 'Stay on for 1 stop');
    });

    test('says nothing when the leg passes none', () {
      // A walk passes no stops; "0 stops" would read as "get off immediately".
      expect(leg({'mode': 'WALK'}).stopsLabel, isNull);
      expect(leg({'stopCount': 0}).stopsLabel, isNull);
    });
  });

  group('waiting', () {
    test('reports a published gap', () {
      expect(leg({'waitMinutes': 4}).waitLabel, 'Wait 4 min');
    });

    test('treats no wait as information, not as missing', () {
      expect(leg({'waitMinutes': 0}).waitLabel, 'Change straight over');
    });

    test('carries whether the wait was measured or assumed', () {
      // Shown in italics with a caveat when estimated: a rider who reads an
      // estimate as a timetable is how someone misses the last service.
      expect(leg({'waitMinutes': 6, 'waitIsEstimated': true}).waitIsEstimated, isTrue);
      expect(leg({'waitMinutes': 4}).waitIsEstimated, isFalse);
    });

    test('says nothing when no wait was supplied', () {
      expect(leg({}).waitLabel, isNull);
    });
  });
}
