import 'package:go_router/go_router.dart';
import '../screens/home_screen.dart';
import '../screens/journey_planner_screen.dart';
import '../screens/route_details_screen.dart';
import '../screens/place_details_screen.dart';
import '../screens/rural_connectivity_screen.dart';
import '../screens/providers_screen.dart';
import '../screens/search_screen.dart';
import '../screens/nearby_explorer_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/assistant_screen.dart';
import '../screens/auth_screen.dart';
import '../screens/profile_screen.dart';

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
      path: '/providers',
      builder: (context, state) => const ProvidersScreen(),
    ),
    GoRoute(
      path: '/provider',
      builder: (context, state) =>
          ProviderDetailScreen(code: state.uri.queryParameters['code']),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/nearby',
      builder: (context, state) => NearbyExplorerScreen(mode: state.uri.queryParameters['mode']),
    ),
    GoRoute(
      path: '/analytics',
      builder: (context, state) => const AnalyticsScreen(),
    ),
    GoRoute(
      path: '/assistant',
      builder: (context, state) => const AssistantScreen(),
    ),
    GoRoute(
      path: '/auth',
      builder: (context, state) => const AuthScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
