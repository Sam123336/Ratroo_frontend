import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/services/assistant_service.dart';

/// The chat bubble is a plain Text widget, so any markdown the model emits is
/// shown literally. These use the exact shapes that appeared on screen.
void main() {
  test('strips the bold markers that showed as literal asterisks', () {
    const raw = '**Total Distance:** 128.2 km\n'
        '**Estimated Fare:** ₹92 (Note: This is an estimate)';

    expect(plainText(raw), 'Total Distance: 128.2 km\n'
        'Estimated Fare: ₹92 (Note: This is an estimate)');
    expect(plainText(raw), isNot(contains('*')));
  });

  test('turns markdown bullets into one consistent mark', () {
    const raw = '**Steps:**\n'
        '1. **Bus:** Take a bus from **Kolkata** to **Arambag (NS)**.\n'
        '    * Duration: ~3 hours 11 minutes.\n'
        '    - Walk to Arambagh Bus Stand.';

    final out = plainText(raw);
    expect(out, contains('• Duration: ~3 hours 11 minutes.'));
    expect(out, contains('• Walk to Arambagh Bus Stand.'));
    expect(out, contains('Take a bus from Kolkata to Arambag (NS).'));
  });

  test('leaves emoji and the arrow itinerary format untouched', () {
    const raw = '🚏 Kolkata → Digha\n'
        '🚌 06:30  WBBus service 112 (3 h 11 m)\n'
        '🚶 Walk to Arambagh Bus Stand (1 min)';

    expect(plainText(raw), raw);
  });

  test('drops heading marks and collapses blank-line runs', () {
    expect(plainText('## Steps\n\n\n\nFirst leg'), 'Steps\n\nFirst leg');
  });

  test('leaves ordinary text alone', () {
    const raw = 'I could not find a route between those two stops.';
    expect(plainText(raw), raw);
  });

  test('an all-markdown or all-whitespace answer collapses to empty', () {
    // The service treats this as a failed reply rather than rendering a blank
    // bubble under a "from live route data" badge.
    expect(plainText('   \n\n  '), isEmpty);
    expect(plainText('**  **'), isEmpty);
  });
}
