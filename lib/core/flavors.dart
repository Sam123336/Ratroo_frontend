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

  /// Dev host. Override without editing code:
  ///   flutter run --dart-define=API_HOST=192.168.1.42
  /// Android emulator uses 10.0.2.2, iOS simulator localhost.
  static const _devHost = String.fromEnvironment('API_HOST', defaultValue: '192.168.1.6');

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
