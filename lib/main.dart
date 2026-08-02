import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme.dart';
import 'core/router.dart';
import 'core/flavors.dart';

void main() {
  runApp(const ProviderScope(child: RatrooApp()));
}

class RatrooApp extends ConsumerWidget {
  const RatrooApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
