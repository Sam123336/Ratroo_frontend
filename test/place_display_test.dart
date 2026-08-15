import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/format.dart';
import 'package:ratroo_app/models/place.dart';

Place _stop(String name, {double? metres, List<String> routes = const []}) =>
    Place(
      id: name,
      canonicalName: name,
      distanceMetres: metres,
      routes: [
        for (final route in routes)
          PlaceRoute(id: route, name: route, providerCode: 'WBBUS'),
      ],
    );

void main() {
  group('titleCaseName', () {
    test('tames operator ALL CAPS', () {
      expect(titleCaseName('KOLKATA'), 'Kolkata');
      expect(titleCaseName('ARAMBAG'), 'Arambag');
    });

    test('leaves initialisms and mixed case alone', () {
      // "BB Ganguly Xing" must not become "Bb Ganguly Xing".
      expect(titleCaseName('BB Ganguly Xing'), 'BB Ganguly Xing');
      expect(titleCaseName('C.R.Ave'), 'C.R.Ave');
      expect(titleCaseName('Kolkata'), 'Kolkata');
    });
  });

  group('distanceLabel', () {
    test('metres up close, kilometres further out', () {
      expect(distanceLabel(84), '80 m');
      expect(distanceLabel(950), '950 m');
      expect(distanceLabel(1420), '1.4 km');
      expect(distanceLabel(23000), '23 km');
    });
  });

  group('mergeSamePlace', () {
    test('collapses the same stop imported under different casing', () {
      final result = mergeSamePlace([
        _stop('KOLKATA', metres: 120),
        _stop('Kolkata', metres: 140),
        _stop('Kolkata', metres: 200),
      ]);

      expect(result.length, 1);
      // The nearest record survives, so the distance shown stays true.
      expect(result.single.distanceMetres, 120);
    });

    test('keeps namesakes that are genuinely far apart', () {
      // Operators name stops after the locality, so two real stops can share
      // a name. Collapsing those would hide services.
      final result = mergeSamePlace([
        _stop('Bazar', metres: 100),
        _stop('Bazar', metres: 4200),
      ]);

      expect(result.length, 2);
    });

    test('without distances nothing is merged', () {
      // Search results carry no distance; a guess there could hide a stop.
      final result = mergeSamePlace([_stop('Kolkata'), _stop('KOLKATA')]);

      expect(result.length, 2);
    });

    test('merged rows keep every operator\'s services', () {
      // The three "Kolkata" cards each carried different routes. Dropping all
      // but the first would have hidden two thirds of the services — worse
      // than the duplication being fixed.
      final result = mergeSamePlace([
        _stop('KOLKATA', metres: 120, routes: ['Bishnupur', 'Chandrakona']),
        _stop('Kolkata', metres: 140, routes: ['Alipurduar', 'Cooch Behar']),
        _stop('Kolkata', metres: 200, routes: ['Arambag', 'Bishnupur']),
      ]);

      expect(result.length, 1);
      expect(
        result.single.routes.map((r) => r.id).toSet(),
        {'Bishnupur', 'Chandrakona', 'Alipurduar', 'Cooch Behar', 'Arambag'},
      );
      // The nearest record supplies identity and distance.
      expect(result.single.distanceMetres, 120);
    });

    test('different stops are never touched', () {
      final result = mergeSamePlace([
        _stop('BB Ganguly Xing', metres: 300),
        _stop('BB Ganguly St.', metres: 310),
      ]);

      expect(result.length, 2);
    });
  });

  group('displayName', () {
    Place named(String name) => Place(id: 'x', canonicalName: name);

    test('stops shouting a name the API stores in caps', () {
      // The same stop read "Chandrakona Road" in search and "CHANDRAKONA ROAD"
      // in Nearby, because only search wrapped its rows in titleCaseName.
      expect(named('KOLKATA').displayName, 'Kolkata');
      expect(named('CHANDRAKONA ROAD').displayName, 'Chandrakona Road');
    });

    test('leaves initialisms and mixed case alone', () {
      expect(named('BB Ganguly St.').displayName, 'BB Ganguly St.');
      expect(named('C.R.Ave').displayName, 'C.R.Ave');
    });

    test('a dotted initialism survives however long it is', () {
      // "C.R." is four characters, so the short-token rule missed it and the
      // Nearby list rendered "C.r. Avenue".
      expect(named('C.R. AVENUE').displayName, 'C.R. Avenue');
      expect(named('B.B.D. BAGH').displayName, 'B.B.D. Bagh');
      // Not an initialism — a normal abbreviation still title-cases.
      expect(named('ST. PAULS').displayName, 'St. Pauls');
    });

    test('canonicalName stays raw for the API and deep links', () {
      // place-details URLs, the WBBUS timetable link and name matching all
      // read canonicalName; title-casing it in place would break them.
      expect(named('KOLKATA').canonicalName, 'KOLKATA');
    });
  });
}
