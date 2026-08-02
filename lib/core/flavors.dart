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

  static String get apiBaseUrl {
    switch (appFlavor) {
      case Flavor.dev:
        // Local network IP for testing on physical device (e.g., Pixel)
        return 'http://192.168.1.10:3000/v1';
      case Flavor.stg:
        return 'https://staging-api.ratroo.com/v1';
      case Flavor.prod:
        return 'https://api.ratroo.com/v1';
    }
  }
}
