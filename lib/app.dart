import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/app_theme.dart';
import 'core/localization/language_provider.dart';
import 'core/providers/app_providers.dart';
import 'features/navigation/main_navigation_screen.dart';
import 'features/settings/screens/pin_lock_screen.dart';

class FertilizerApp extends ConsumerStatefulWidget {
  const FertilizerApp({super.key});

  @override
  ConsumerState<FertilizerApp> createState() => _FertilizerAppState();
}

class _FertilizerAppState extends ConsumerState<FertilizerApp> {
  bool _isAuthenticated = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(businessSettingsProvider);
    final currentLang = ref.watch(languageProvider);

    return MaterialApp(
      title: 'Fertilizer Business ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      locale: Locale(currentLang),
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('ur', 'PK'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: settingsAsync.when(
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, _) => const MainNavigationScreen(),
        data: (settings) {
          if (settings.isPinEnabled && !_isAuthenticated) {
            return PinLockScreen(
              onUnlocked: () {
                setState(() => _isAuthenticated = true);
              },
            );
          }
          return const MainNavigationScreen();
        },
      ),
    );
  }
}
