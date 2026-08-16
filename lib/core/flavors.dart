import 'package:flutter/foundation.dart';

enum Flavor {
  dev,
  stg,
  prod,
}

class AppFlavors {
  static Flavor appFlavor = Flavor.dev;

  static String get name => appFlavor.name;

  static String get title {
    switch (appFlavor) {
      case Flavor.dev:
        return 'Ratroo Dev';
      case Flavor.stg:
        return 'Ratroo Staging';
      case Flavor.prod:
        return 'Ratroo';
    }
  }

  /// Explicit override, and the only thing that works on a *physical* device:
  ///   flutter run --dart-define=API_HOST=192.168.1.13
  static const _apiHostOverride = String.fromEnvironment('API_HOST');

  /// Where the dev API lives, per platform.
  ///
  /// This was a hardcoded `192.168.1.6`. That address is not this machine and
  /// may not be any machine — a LAN IP is a fact about one afternoon's DHCP
  /// lease, and pinning one in source means the app silently stops reaching
  /// the backend the next time the router hands out a different number. It
  /// showed up as "Can't reach Ratroo. Check your connection." with a
  /// perfectly healthy server running on :3000.
  ///
  /// An Android emulator cannot use the host's loopback at all: 127.0.0.1
  /// inside the emulator is the emulator. `10.0.2.2` is the alias the Android
  /// emulator maps to the host machine, and it survives any IP change.
  ///
  /// A physical phone is the one case with no correct default — it needs the
  /// machine's LAN address, which only you know. Hence [_apiHostOverride].
  static String get _devHost {
    if (_apiHostOverride.isNotEmpty) return _apiHostOverride;
    if (kIsWeb) return 'localhost';
    return defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
  }

  /// Vercel project alias — stays valid across deploys. The per-deployment URL
  /// (`ratroo-backend-<buildId>-…`) dies the moment you ship again, so don't pin it.
  /// Swap for api.ratroo.com once that domain is attached in Vercel.
  static const _vercelHost = 'ratroo-backend-sams-projects-83758424.vercel.app';

  /// Point any build at any host:
  ///   flutter run --dart-define=API_BASE_URL=https://example.com/v1
  static const _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.isNotEmpty) {
      return _apiBaseUrlOverride;
    }

    switch (appFlavor) {
      case Flavor.dev:
        // Local network IP for testing on physical device (e.g., Pixel)
        return 'http://$_devHost:3000/v1';
      case Flavor.stg:
      case Flavor.prod:
        return 'https://$_vercelHost/v1';
    }
  }
}
