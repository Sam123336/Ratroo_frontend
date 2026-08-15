import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ratroo_app/widgets/app_shell.dart';

/// The five destinations used to be `context.push`ed from a bar that only
/// Home drew. Three things followed, and each is pinned here:
///
///  * the bar vanished once you left Home,
///  * tabs stacked instead of switching,
///  * nothing was ever marked current except Home, which was hardcoded to 0.
///
/// The screens themselves need a network, a location fix and a Riverpod scope,
/// so this drives the real `StatefulShellRoute` with stand-in pages. What is
/// under test is the shell, not what the branches happen to render.
void main() {
  Widget page(String label) =>
      Scaffold(body: Center(child: Text(label, key: ValueKey(label))));

  StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => page(label))],
  );

  GoRouter buildRouter() => GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          branch('/', 'home'),
          branch('/journey-planner', 'plan'),
          branch('/nearby', 'nearby'),
          branch('/assistant', 'ask'),
          branch('/profile', 'profile'),
        ],
      ),
      // A drill-down, deliberately outside the shell: a route timetable takes
      // the whole screen and must cover the bar rather than sit under it.
      GoRoute(path: '/route-details', builder: (_, _) => page('details')),
    ],
  );

  Future<void> pump(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
  }

  int selectedIndex(WidgetTester tester) =>
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  testWidgets('the bar survives leaving Home', (tester) async {
    final router = buildRouter();
    await pump(tester, router);

    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nearby')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('the current tab is the one marked current', (tester) async {
    final router = buildRouter();
    await pump(tester, router);
    expect(selectedIndex(tester), 0);

    await tester.tap(find.text('Ask'));
    await tester.pumpAndSettle();

    expect(selectedIndex(tester), 3);
    expect(find.byKey(const ValueKey('ask')), findsOneWidget);
  });

  testWidgets('tabs switch rather than stacking', (tester) async {
    final router = buildRouter();
    await pump(tester, router);

    for (final label in ['Plan', 'Nearby', 'Ask', 'Profile']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    // Four tabs later there is still nothing to go back to: these are five
    // top-level places, not a five-deep history.
    expect(router.canPop(), isFalse);
    expect(find.byKey(const ValueKey('profile')), findsOneWidget);
    expect(find.byKey(const ValueKey('home')), findsNothing);
  });

  testWidgets('a tab keeps its own stack while you visit another', (
    tester,
  ) async {
    final router = buildRouter();
    await pump(tester, router);

    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('nearby')), findsOneWidget);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nearby')), findsOneWidget);
    expect(selectedIndex(tester), 2);
  });

  testWidgets('tapping the current tab returns it to its root', (tester) async {
    final router = buildRouter();
    await pump(tester, router);

    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();
    router.push('/route-details');
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('details')), findsOneWidget);

    // The drill-down covers the bar, so pop back to it before re-tapping.
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nearby'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('nearby')), findsOneWidget);
    expect(router.canPop(), isFalse);
  });
}
