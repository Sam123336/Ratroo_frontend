import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/journey_planner_screen.dart';
import '../screens/route_details_screen.dart';
import '../screens/place_details_screen.dart';
import '../screens/providers_screen.dart';
import '../screens/search_screen.dart';
import '../screens/nearby_explorer_screen.dart';
import '../screens/assistant_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/profile_screen.dart';

/// Every screen here is a drill-down from a list: a stop card opens its
/// details, a search result opens a route. Material calls that a parent-child
/// move, and its motion is the scaled shared axis — the arriving screen grows
/// forward while the list falls back, so the two read as one surface rather
/// than two unrelated pages.
///
/// Done as a route transition, not `OpenContainer`: that widget builds the
/// destination inline, which would take these screens out of go_router and
/// cost every deep link in the app.
CustomTransitionPage<void> _drillDown(LocalKey key, Widget child) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: drillDownTransition,
  );
}

/// Public so a test can pin the reduce-motion branch: a rider who has asked
/// the system to stop moving things must get the page, not a quieter animation.
Widget drillDownTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  if (MediaQuery.disableAnimationsOf(context)) return child;
  return SharedAxisTransition(
    animation: animation,
    secondaryAnimation: secondaryAnimation,
    transitionType: SharedAxisTransitionType.scaled,
    fillColor: Theme.of(context).scaffoldBackgroundColor,
    child: child,
  );
}

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/journey-planner',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, const JourneyPlannerScreen()),
    ),
    GoRoute(
      path: '/route-details',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, RouteDetailsScreen(routeId: state.uri.queryParameters['id'])),
    ),
    GoRoute(
      path: '/place-details',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, PlaceDetailsScreen(placeId: state.uri.queryParameters['id'])),
    ),
    GoRoute(
      path: '/providers',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, const ProvidersScreen()),
    ),
    GoRoute(
      path: '/provider',
      pageBuilder: (context, state) => _drillDown(
        state.pageKey,
        ProviderDetailScreen(code: state.uri.queryParameters['code']),
      ),
    ),
    GoRoute(
      path: '/search',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, const SearchScreen()),
    ),
    GoRoute(
      path: '/nearby',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, NearbyExplorerScreen(mode: state.uri.queryParameters['mode'])),
    ),
    GoRoute(
      path: '/assistant',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, const AssistantScreen()),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/profile',
      pageBuilder: (context, state) =>
          _drillDown(state.pageKey, const ProfileScreen()),
    ),
  ],
);
