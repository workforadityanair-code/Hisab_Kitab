import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'dashboard_screen.dart';
import 'lock_gate.dart';
import 'settings.dart';
import 'setup_screen.dart';
import 'store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await appSettings.load();
  appStore.load();
  runApp(const HisabKitabApp());
}

class HisabKitabApp extends StatelessWidget {
  const HisabKitabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => DynamicColorBuilder(
        builder: (lightDynamic, darkDynamic) {
          final useDynamic = appSettings.useDynamicColor;
          final accent = appSettings.accent;
          return MaterialApp(
            title: 'HisabKitab',
            theme: buildTheme(
              schemeFor(
                useDynamic ? lightDynamic : null,
                Brightness.light,
                accent,
              ),
            ),
            darkTheme: buildTheme(
              schemeFor(
                useDynamic ? darkDynamic : null,
                Brightness.dark,
                accent,
              ),
            ),
            themeMode: appSettings.themeMode,
            debugShowCheckedModeBanner: false,
            builder: (context, child) =>
                LockGate(child: child ?? const SizedBox.shrink()),
            home: const _Home(),
          );
        },
      ),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: appStore,
      builder: (context, _) {
        if (!appStore.loaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!appStore.hasProfile) return const SetupScreen(firstRun: true);
        return const DashboardScreen();
      },
    );
  }
}
