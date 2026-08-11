import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/flavors.dart';
import 'providers/api_providers.dart';

void main() {
  runApp(const ProviderScope(child: RatrooApp()));
}

class RatrooApp extends ConsumerStatefulWidget {
  const RatrooApp({super.key});

  @override
  ConsumerState<RatrooApp> createState() => _RatrooAppState();
}

class _RatrooAppState extends ConsumerState<RatrooApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ask for a fix as the app opens, so the permission prompt happens once at
    // launch and every screen that needs "near me" already has an answer.
    // Fire and forget: LocationService never throws, and a refusal is a valid
    // result the screens render as a banner.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(userLocationProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app is the moment the shown location is most likely to
  /// be wrong — the user may have travelled since. Checked here rather than on
  /// a timer, which would wake the GPS while nobody is looking.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      checkLocationDrift(ref, mounted: () => mounted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppFlavors.title,
      debugShowCheckedModeBanner: AppFlavors.appFlavor == Flavor.dev,
      theme: RatrooTheme.lightTheme,
      darkTheme: RatrooTheme.darkTheme,
      themeMode: ThemeMode.system, // Supports both dark and light modes
      routerConfig: goRouter,
    );
  }
}
