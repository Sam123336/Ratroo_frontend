import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../services/search_service.dart';
import '../services/transit_service.dart';
import '../services/journey_service.dart';
import '../services/connectivity_service.dart';
import '../services/nearby_service.dart';
import '../services/analytics_service.dart';
import '../services/favorites_service.dart';

// Global API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
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
