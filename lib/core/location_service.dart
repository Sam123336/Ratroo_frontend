import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Where the app thinks the user is, and how sure it is.
enum LocationStatus {
  /// A real GPS fix.
  live,

  /// Permission refused, or location off. Using the fallback.
  denied,

  /// Permission permanently refused — only Settings can undo it.
  deniedForever,

  /// Location services disabled device-wide.
  serviceDisabled,

  /// A fix was requested but never arrived in time.
  unavailable,
}

class UserLocation {
  final double latitude;
  final double longitude;
  final LocationStatus status;

  const UserLocation({
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  bool get isLive => status == LocationStatus.live;

  /// Kolkata centre (Esplanade). Used when there is no fix, so the app still
  /// shows something useful rather than an empty screen.
  static const fallback = UserLocation(
    latitude: 22.5726,
    longitude: 88.3639,
    status: LocationStatus.denied,
  );
}

/// Device location, with every failure mode turned into a usable answer.
///
/// Nearby search previously used the hardcoded Kolkata centre for everyone, so
/// a user in Bardhaman saw stops 100km away described as "nearby".
class LocationService {
  /// How long a fix is reused before we ask the OS again. Short, because a
  /// rider moves: an unexpiring cache pinned "nearby" to wherever the app
  /// happened to open for the rest of the session.
  static const cacheFor = Duration(minutes: 2);

  /// The OS's last-known fix can be hours old and from another city. Past this
  /// age we pay for a real one rather than trust it.
  static const staleFix = Duration(minutes: 5);

  /// Cached so repeated screen builds don't each trigger a GPS fix.
  UserLocation? _last;
  DateTime? _lastAt;

  UserLocation? get lastKnown => _last;

  /// Never throws. A refused permission is an answer, not an error — the caller
  /// gets the fallback with a status explaining why.
  Future<UserLocation> current({bool forceRefresh = false}) async {
    final fresh = _lastAt != null && DateTime.now().difference(_lastAt!) < cacheFor;
    if (!forceRefresh && fresh && _last != null && _last!.isLive) return _last!;

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return _remember(_fallbackWith(LocationStatus.serviceDisabled));
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        return _remember(_fallbackWith(LocationStatus.deniedForever));
      }

      if (permission == LocationPermission.denied) {
        return _remember(_fallbackWith(LocationStatus.denied));
      }

      // A recent last-known fix is instant and good enough for "what's nearby".
      final cached = await Geolocator.getLastKnownPosition();
      if (_usable(cached)) return _remember(_live(cached!));

      try {
        return _remember(_live(await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 12),
          ),
        )));
      } catch (error) {
        // No fresh fix. An old real position still beats Kolkata centre — it is
        // where the user last was, which is usually where they still are.
        // Discarding it for a hardcoded city was why "Retry" kept answering
        // "could not get your location" on a device that had a position all
        // along.
        debugPrint('LocationService: no fresh fix ($error)');
        if (cached != null) return _remember(_live(cached));
        rethrow;
      }
    } catch (error) {
      debugPrint('LocationService: no fix at all ($error)');
      return _remember(_fallbackWith(LocationStatus.unavailable));
    }
  }

  /// Opens the OS settings page so a permanently-denied user can recover.
  Future<void> openSettings() => Geolocator.openAppSettings();

  UserLocation _fallbackWith(LocationStatus status) => UserLocation(
        latitude: UserLocation.fallback.latitude,
        longitude: UserLocation.fallback.longitude,
        status: status,
      );

  static UserLocation _live(Position position) => UserLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        status: LocationStatus.live,
      );

  /// A last-known fix is only worth using while it is recent.
  static bool _usable(Position? position) =>
      position != null && DateTime.now().difference(position.timestamp) < staleFix;

  UserLocation _remember(UserLocation location) {
    _last = location;
    _lastAt = DateTime.now();
    return location;
  }
}

/// Straight-line metres between two points. Not walking distance — we have no
/// pedestrian network to route over, so treat it as a lower bound.
double distanceMetres(double lat1, double lon1, double lat2, double lon2) =>
    Geolocator.distanceBetween(lat1, lon1, lat2, lon2);

/// Human-readable reason, for the banner shown when the fallback is in use.
String locationStatusMessage(LocationStatus status) {
  switch (status) {
    case LocationStatus.live:
      return '';
    case LocationStatus.serviceDisabled:
      return 'Location is turned off. Showing stops near Kolkata centre.';
    case LocationStatus.deniedForever:
      return 'Location permission is blocked. Enable it in Settings to see stops near you.';
    case LocationStatus.denied:
      return 'Location permission not granted. Showing stops near Kolkata centre.';
    case LocationStatus.unavailable:
      return 'Could not get your location. Showing stops near Kolkata centre.';
  }
}
