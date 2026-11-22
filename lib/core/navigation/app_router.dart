import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/main_shell.dart';
import 'package:acl_rehab/presentation/screens/onboarding_screen.dart';
import 'package:acl_rehab/presentation/screens/reassessment_result_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  const AppRoutes._();

  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
  static const retake = '/assessment/retake';
  static const reassess = '/assessment/reassess';
  static const results = '/assessment/results';

  static String resultsFor(String recordId) => '$results/$recordId';
}

/// A single router for the app's lifetime. It re-evaluates its redirect when
/// onboarding status changes, instead of being rebuilt on every state change
/// (which would reset navigation).
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  ref.listen(
    appControllerProvider.select((value) => value.value?.onboardingCompleted),
    (_, _) => refresh.value++,
  );

  bool onboardingCompleted() =>
      ref.read(appControllerProvider).value?.onboardingCompleted ?? false;

  final router = GoRouter(
    initialLocation: onboardingCompleted()
        ? AppRoutes.dashboard
        : AppRoutes.onboarding,
    refreshListenable: refresh,
    redirect: (context, state) {
      final completed = onboardingCompleted();
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!completed && !isOnboarding) return AppRoutes.onboarding;
      if (completed && isOnboarding) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: AppRoutes.retake,
        builder: (context, state) =>
            const OnboardingScreen(mode: AssessmentMode.retake),
      ),
      GoRoute(
        path: AppRoutes.reassess,
        builder: (context, state) =>
            const OnboardingScreen(mode: AssessmentMode.reassessment),
      ),
      GoRoute(
        path: '${AppRoutes.results}/:recordId',
        builder: (context, state) => ReassessmentResultScreen(
          recordId: state.pathParameters['recordId'] ?? '',
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
