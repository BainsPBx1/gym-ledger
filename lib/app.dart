import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'screens/lock_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/shell.dart';
import 'state/providers.dart';
import 'theme/app_theme.dart';

class GymLedgerApp extends ConsumerWidget {
  const GymLedgerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final themeMode = switch (settings.valueOrNull?.themeMode) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system, // respect system preference by default
    };
    return MaterialApp(
      title: 'Gym Ledger',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: settings.when(
        loading: () => const Scaffold(body: SizedBox.shrink()),
        error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
        data: (s) => !s.onboarded
            ? const OnboardingScreen()
            : s.biometricLock
                ? const LockScreen()
                : const HomeShell(),
      ),
    );
  }
}
