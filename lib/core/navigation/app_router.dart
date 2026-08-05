import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/presentation/screens/main_shell.dart';
import 'package:acl_rehab/presentation/screens/onboarding_screen.dart';
import 'package:go_router/go_router.dart';

class AppRoutes {
  const AppRoutes._();

  static const onboarding = '/onboarding';
  static const dashboard = '/dashboard';
}

GoRouter createAppRouter({
  required bool onboardingCompleted,
  Assessment? existingAssessment,
}) {
  return GoRouter(
    initialLocation: onboardingCompleted
        ? AppRoutes.dashboard
        : AppRoutes.onboarding,
    redirect: (context, state) {
      final isOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!onboardingCompleted && !isOnboarding) {
        return AppRoutes.onboarding;
      }
      if (onboardingCompleted && isOnboarding) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) =>
            OnboardingScreen(initialAssessment: existingAssessment),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => const MainShell(),
      ),
    ],
  );
}
