import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/flavors.dart';
import 'main.dart';

void main() {
  AppFlavors.appFlavor = Flavor.dev;
  runApp(const ProviderScope(child: RatrooApp()));
}
