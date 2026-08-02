import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/journey_planner_screen.dart';
import '../screens/route_details_screen.dart';
import '../screens/place_details_screen.dart';
import '../screens/rural_connectivity_screen.dart';
import '../screens/nearby_explorer_screen.dart';
import '../screens/analytics_screen.dart';

final goRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/journey-planner',
      builder: (context, state) => const JourneyPlannerScreen(),
    ),
    GoRoute(
      path: '/route-details',
      builder: (context, state) => RouteDetailsScreen(routeId: state.uri.queryParameters['id']),
    ),
    GoRoute(
      path: '/place-details',
      builder: (context, state) => PlaceDetailsScreen(placeId: state.uri.queryParameters['id']),
    ),
    GoRoute(
      path: '/rural',
      builder: (context, state) => const RuralConnectivityScreen(),
    ),
    GoRoute(
      path: '/nearby',
      builder: (context, state) => const NearbyExplorerScreen(),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
  ],
);
