import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/location_service.dart';
import '../services/assistant_service.dart';
import '../services/auth_service.dart';
import '../services/search_service.dart';
import '../services/transit_service.dart';
import '../services/journey_service.dart';
import '../services/connectivity_service.dart';
import '../services/nearby_service.dart';
import '../services/favorites_service.dart';

/// Wall clock, injectable so time-of-day logic (which departure is "next")
/// can be tested without waiting for a particular hour.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Device location, shared by every screen that needs "near me".
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

/// The user's position, or the Kolkata fallback with a status explaining why.
/// Never fails — a refused permission is an answer, not an error.
final userLocationProvider = FutureProvider<UserLocation>((ref) async {
  return ref.watch(locationServiceProvider).current();
});

/// How far the device may drift before the screen is considered stale. Roughly
/// "a different neighbourhood", not "crossed the road".
const kLocationDriftMetres = 1500.0;

/// Set when the device has moved away from the position the UI was built from,
/// so the app can offer a refresh instead of quietly showing the wrong city.
/// Null means what is on screen still matches where the user is.
final locationDriftProvider = StateProvider<UserLocation?>((ref) => null);

/// The position to prompt about, or null if the screen is still accurate.
///
/// Only real fixes are compared. Drifting between two fallbacks says nothing
/// about where the user is, and prompting "you have moved" off the Kolkata
/// default would be a lie.
UserLocation? driftedTo(UserLocation? shown, UserLocation actual) {
  if (shown == null || !shown.isLive || !actual.isLive) return null;

  final moved = distanceMetres(
      shown.latitude, shown.longitude, actual.latitude, actual.longitude);

  return moved >= kLocationDriftMetres ? actual : null;
}

/// Re-reads the device position and reports whether it has drifted from what
/// the UI is showing. Called when the app returns to the foreground.
Future<void> checkLocationDrift(WidgetRef ref) async {
  final shown = ref.read(userLocationProvider).valueOrNull;
  if (shown == null || !shown.isLive) return;

  final actual = await ref.read(locationServiceProvider).current(forceRefresh: true);

  ref.read(locationDriftProvider.notifier).state = driftedTo(shown, actual);
}

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

// Assistant Service Provider
final assistantServiceProvider = Provider<AssistantService>((ref) {
  return AssistantService(ref.watch(apiClientProvider));
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


// Favorites Service Provider
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final client = ref.watch(apiClientProvider);
  return FavoritesService(client);
});
