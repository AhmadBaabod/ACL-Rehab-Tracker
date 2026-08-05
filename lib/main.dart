import 'dart:async';

import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrintStack(stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Unhandled platform error: $error');
    debugPrintStack(stackTrace: stack);
    return true;
  };

  await Hive.initFlutter();
  final stateBox = await Hive.openBox<String>(AppStateRepository.boxName);
  final prefs = await SharedPreferences.getInstance();

  runZonedGuarded(
    () {
      runApp(
        ProviderScope(
          overrides: [
            appStateRepositoryProvider.overrideWithValue(
              AppStateRepository(stateBox, prefs),
            ),
          ],
          child: const ACLRecoveryCoachApp(),
        ),
      );
    },
    (error, stack) {
      debugPrint('Unhandled zone error: $error');
      debugPrintStack(stackTrace: stack);
    },
  );
}

class ACLRecoveryCoachApp extends ConsumerWidget {
  const ACLRecoveryCoachApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return appStateAsync.when(
          data: (appState) {
            final themeMode = appState.themeMode == ThemeMode.dark.name
                ? ThemeMode.dark
                : appState.themeMode == ThemeMode.light.name
                ? ThemeMode.light
                : ThemeMode.system;
            final router = createAppRouter(
              onboardingCompleted: appState.onboardingCompleted,
              existingAssessment: appState.assessment,
            );

            return MaterialApp.router(
              title: 'ACL Recovery Coach',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme(dynamicScheme: lightDynamic),
              darkTheme: AppTheme.darkTheme(dynamicScheme: darkDynamic),
              themeMode: themeMode,
              routerConfig: router,
            );
          },
          loading: () => MaterialApp(
            title: 'ACL Recovery Coach',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(dynamicScheme: lightDynamic),
            darkTheme: AppTheme.darkTheme(dynamicScheme: darkDynamic),
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (error, stack) => MaterialApp(
            title: 'ACL Recovery Coach',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(dynamicScheme: lightDynamic),
            darkTheme: AppTheme.darkTheme(dynamicScheme: darkDynamic),
            home: Scaffold(
              body: Center(child: Text('Unable to start app: $error')),
            ),
          ),
        );
      },
    );
  }
}
