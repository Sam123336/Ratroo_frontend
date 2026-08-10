import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/format.dart';
import 'package:ratroo_app/models/place.dart';

Place _stop(String name, {double? metres}) =>
    Place(id: name, canonicalName: name, distanceMetres: metres);

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

  group('dedupeSamePlace', () {
    test('collapses the same stop imported under different casing', () {
      final result = dedupeSamePlace([
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
      final result = dedupeSamePlace([
        _stop('Bazar', metres: 100),
        _stop('Bazar', metres: 4200),
      ]);

      expect(result.length, 2);
    });

    test('without distances nothing is merged', () {
      // Search results carry no distance; a guess there could hide a stop.
      final result = dedupeSamePlace([_stop('Kolkata'), _stop('KOLKATA')]);

      expect(result.length, 2);
    });

    test('different stops are never touched', () {
      final result = dedupeSamePlace([
        _stop('BB Ganguly Xing', metres: 300),
        _stop('BB Ganguly St.', metres: 310),
      ]);

      expect(result.length, 2);
    });
  });
}
