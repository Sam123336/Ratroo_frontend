import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../services/auth_service.dart';
import '../services/search_service.dart';
import '../services/transit_service.dart';
import '../services/journey_service.dart';
import '../services/connectivity_service.dart';
import '../services/nearby_service.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';

/// Bumped when a refresh fails unrecoverably. A separate provider rather than
/// invalidating currentUserProvider directly, which would make apiClient and
/// currentUser depend on each other.
final sessionExpiredProvider = StateProvider<int>((ref) => 0);

// Global API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onSessionExpired: () => ref.read(sessionExpiredProvider.notifier).state++,
  );
});

// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(apiClientProvider));
});

/// Who is signed in, or null. Read this to gate UI; invalidate it after
/// login/logout to re-resolve.
final currentUserProvider = FutureProvider<AuthUser?>((ref) async {
  ref.watch(sessionExpiredProvider); // re-resolve when the session dies
  return ref.watch(authServiceProvider).currentUser();
});

// Search Service Provider
final searchServiceProvider = Provider<SearchService>((ref) {
  final client = ref.watch(apiClientProvider);
  return SearchService(client);
});

// Transit Service Provider
final transitServiceProvider = Provider<TransitService>((ref) {
  final client = ref.watch(apiClientProvider);
  return TransitService(client);
});

// Journey Service Provider
final journeyServiceProvider = Provider<JourneyService>((ref) {
  final client = ref.watch(apiClientProvider);
  return JourneyService(client);
});

// Connectivity Service Provider
final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  final client = ref.watch(apiClientProvider);
  return ConnectivityService(client);
});

// Nearby Service Provider
final nearbyServiceProvider = Provider<NearbyService>((ref) {
  final client = ref.watch(apiClientProvider);
  return NearbyService(client);
});

// Analytics Service Provider
final analyticsServiceProvider = Provider<AnalyticsService>((ref) {
  final client = ref.watch(apiClientProvider);
  return AnalyticsService(client);
});

// Favorites Service Provider
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final client = ref.watch(apiClientProvider);
  return FavoritesService(client);
});
