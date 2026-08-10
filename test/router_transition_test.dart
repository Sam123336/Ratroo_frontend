import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ratroo_app/core/router.dart';

/// Renders the transition under a given reduce-motion setting and reports
/// whether the animated wrapper survived.
Future<bool> _animates(WidgetTester tester, {required bool disabled}) async {
  const marker = SizedBox(key: ValueKey('page'));

  await tester.pumpWidget(
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: disabled),
        child: Builder(
          builder: (context) => drillDownTransition(
            context,
            const AlwaysStoppedAnimation(1),
            const AlwaysStoppedAnimation(0),
            marker,
          ),
        ),
      ),
    ),
  );

  expect(find.byKey(const ValueKey('page')), findsOneWidget);
  return find.byType(SharedAxisTransition).evaluate().isNotEmpty;
}

void main() {
  testWidgets('drill-down uses a shared axis by default', (tester) async {
    expect(await _animates(tester, disabled: false), isTrue);
  });

  testWidgets('reduce motion gets the page with no transition', (tester) async {
    expect(await _animates(tester, disabled: true), isFalse);
  });
}
