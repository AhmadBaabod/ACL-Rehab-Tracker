import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:acl_rehab/presentation/widgets/training_setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return appStateAsync.when(
      data: (appState) {
        final currentMode = ThemeMode.values.firstWhere(
          (mode) => mode.name == appState.themeMode,
          orElse: () => ThemeMode.system,
        );

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Program',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ACL Recovery Coach guides your recovery after ACL surgery.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const ClinicalDisclaimerBanner(),
                      const SizedBox(height: AppConstants.sectionGap),
                      SectionHeader(title: 'Settings'),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(
                            AppConstants.cardPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Appearance',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              SegmentedButton<ThemeMode>(
                                segments: const [
                                  ButtonSegment(
                                    value: ThemeMode.system,
                                    icon: Icon(Icons.brightness_auto_outlined),
                                    label: Text('System'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.light,
                                    icon: Icon(Icons.light_mode_outlined),
                                    label: Text('Light'),
                                  ),
                                  ButtonSegment(
                                    value: ThemeMode.dark,
                                    icon: Icon(Icons.dark_mode_outlined),
                                    label: Text('Dark'),
                                  ),
                                ],
                                selected: {currentMode},
                                onSelectionChanged: (selection) async {
                                  HapticFeedback.selectionClick();
                                  await ref
                                      .read(appControllerProvider.notifier)
                                      .updateThemeMode(selection.first);
                                },
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Weight unit',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 10),
                              SegmentedButton<WeightUnit>(
                                segments: const [
                                  ButtonSegment(
                                    value: WeightUnit.kg,
                                    label: Text('Kilograms (kg)'),
                                  ),
                                  ButtonSegment(
                                    value: WeightUnit.lb,
                                    label: Text('Pounds (lb)'),
                                  ),
                                ],
                                selected: {appState.weightUnit},
                                onSelectionChanged: (selection) async {
                                  HapticFeedback.selectionClick();
                                  await ref
                                      .read(appControllerProvider.notifier)
                                      .updateWeightUnit(selection.first);
                                },
                              ),
                              const SizedBox(height: 18),
                              const Divider(height: 1),
                              const SizedBox(height: 18),
                              Text(
                                'Training setup',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Change your goal, days, time, or equipment. Your plan updates to match.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      showTrainingSetupSheet(context, ref),
                                  icon: const Icon(Icons.tune),
                                  label: const Text('Edit training setup'),
                                ),
                              ),
                              const SizedBox(height: 18),
                              const Divider(height: 1),
                              const SizedBox(height: 18),
                              Text(
                                'Assessment',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'To log progress, use Reassess on the Progress tab. Only redo this if you entered something wrong.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      _confirmRetakeAssessment(context, ref),
                                  icon: const Icon(Icons.restart_alt),
                                  label: const Text(
                                    'Correct Initial Assessment',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppConstants.sectionGap),
                      _section(
                        context,
                        icon: Icons.volunteer_activism_outlined,
                        title: 'How it works',
                        body:
                            'You move forward based on how your knee is doing, not just the date.',
                      ),
                      _section(
                        context,
                        icon: Icons.science_outlined,
                        title: 'Your exercises',
                        body:
                            'Rate each exercise. Two "Just right" with low pain makes it harder. "Too hard" or pain 5/10 makes it easier.',
                      ),
                      _section(
                        context,
                        icon: Icons.rule_outlined,
                        title: 'Locked exercises',
                        body: 'Harder drills unlock when your knee is ready.',
                      ),
                      _section(
                        context,
                        icon: Icons.medical_information_outlined,
                        title: 'Medical Disclaimer',
                        body:
                            'This app is a guide only. Your surgeon and physio always come first.',
                        accent: AppTheme.softRed,
                      ),
                      _graftSection(context),
                      _section(
                        context,
                        icon: Icons.menu_book_outlined,
                        title: 'Learn as you go',
                        body:
                            'See why drills are locked and what you need to unlock them.',
                      ),
                      _section(
                        context,
                        icon: Icons.source_outlined,
                        title: 'Sources',
                        body:
                            'Based on ACL guidelines from Mass General Brigham, Ohio State, Aspetar, MOON, and the University of Delaware.',
                      ),
                      _section(
                        context,
                        icon: Icons.autorenew,
                        title: 'Your plan changes with you',
                        body:
                            'Assessment, plan, workouts, retest, new plan. When you improve, the app asks you to retest and updates your plan.',
                      ),
                      _section(
                        context,
                        icon: Icons.lock_outline,
                        title: 'Your Data',
                        body:
                            'Everything stays on this device. Nothing is uploaded.',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Unable to load about screen: $error')),
      ),
    );
  }

  Future<void> _confirmRetakeAssessment(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.restart_alt),
        title: const Text('Correct initial assessment?'),
        content: const Text(
          'You will answer every question again. Your workouts are kept. To log progress, use Reassess instead.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    context.push(AppRoutes.retake);
  }

  Widget _graftSection(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.biotech_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Graft Considerations',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...GraftType.values.map(
              (graft) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      graft.label,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    ...graft.educationPoints
                        .take(2)
                        .map(
                          (point) => Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('- '),
                              Expanded(child: Text(point)),
                            ],
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    Color? accent,
  }) {
    final color = accent ?? Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.cardPadding),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(body, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
