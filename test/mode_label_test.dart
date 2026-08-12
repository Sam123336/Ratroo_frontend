import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/theme.dart';

void main() {
  group('modeColor', () {
    test('every mode the backend can project has a colour', () {
      // A mode with no entry falls back to primary blue, which would make an
      // auto route indistinguishable from a bus.
      for (final mode in ['bus', 'rail', 'ferry', 'tram', 'metro', 'auto', 'shared_auto']) {
        expect(
          RatrooTheme.modeColors.containsKey(mode),
          isTrue,
          reason: '$mode has no colour of its own',
        );
      }
    });

    test('auto is distinct from bus', () {
      expect(RatrooTheme.modeColor('auto'), isNot(RatrooTheme.modeColor('bus')));
      expect(
        RatrooTheme.modeColor('shared_auto'),
        isNot(RatrooTheme.modeColor('auto')),
      );
    });

    test('an unknown mode still renders rather than throwing', () {
      expect(RatrooTheme.modeColor('hovercraft'), RatrooTheme.primaryColor);
      expect(RatrooTheme.modeColor(null), RatrooTheme.primaryColor);
    });
  });
}
