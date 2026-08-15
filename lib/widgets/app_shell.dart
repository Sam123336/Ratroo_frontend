import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/app_icons.dart';
import '../core/theme.dart';

/// The five top-level destinations and the bar that switches between them.
///
/// This bar used to be built inside `HomeScreen`, and every other destination
/// was `context.push`ed on top of it. Three things followed from that, all of
/// them wrong:
///
///  * The bar disappeared the moment you left Home, so Plan → Nearby meant
///    going back to Home first. Navigation was not persistent.
///  * Tabs stacked. Home → Plan → Nearby → Ask → Profile was a five-deep
///    back stack of things that are all top level.
///  * Nothing was ever marked current except Home, which was hardcoded to
///    index 0 whether you were looking at it or not.
///
/// A `StatefulShellRoute` fixes all three at once and gives each tab its own
/// navigator, so scroll position, typed input and drill-downs survive a trip
/// to another tab and back.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  /// Bottom padding a scrolling tab root must reserve so its last row is not
  /// hidden under the floating bar. The bar is 68 high, sits 16 off the bottom
  /// edge, and clears the gesture inset itself.
  static const double contentInset = 100;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(AppIcons.home),
      selectedIcon: Icon(AppIcons.homeSelected),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(AppIcons.alternatives),
      selectedIcon: Icon(AppIcons.alternativesSelected),
      label: 'Plan',
    ),
    // Was a bookmark, which is a different promise: this tab shows what is
    // around the rider now, not what they saved.
    NavigationDestination(
      icon: Icon(AppIcons.nearMe),
      selectedIcon: Icon(AppIcons.nearMeSelected),
      label: 'Nearby',
    ),
    NavigationDestination(
      icon: Icon(AppIcons.assistant),
      selectedIcon: Icon(AppIcons.assistantSolid),
      label: 'Ask',
    ),
    NavigationDestination(
      icon: Icon(AppIcons.user),
      selectedIcon: Icon(AppIcons.userSelected),
      label: 'Profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      // The bar floats over the content rather than sitting in a slab below
      // it; each tab root reserves [contentInset] at the end of its scroll.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          RatrooTheme.space4,
          0,
          RatrooTheme.space4,
          RatrooTheme.space4,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(RatrooTheme.radiusXl),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
              boxShadow: RatrooTheme.cardShadow(theme.brightness),
            ),
            child: NavigationBar(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: _destinations,
            ),
          ),
        ),
      ),
    );
  }

  /// `initialLocation: true` when the tab is already current pops that branch
  /// back to its root — the platform behaviour on both iOS and Android, and
  /// the only way out of a deep drill-down without hunting for the back arrow.
  void _onDestinationSelected(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );
}
