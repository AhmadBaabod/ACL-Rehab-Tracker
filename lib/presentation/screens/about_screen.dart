import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
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
                        'ACL Recovery Coach is a criteria-based recovery companion for people after ACL reconstruction.',
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
                              const Divider(height: 1),
                              const SizedBox(height: 18),
                              Text(
                                'Assessment',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Retake the initial assessment if your symptoms, restrictions, graft details, or surgery timeline need to be corrected.',
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
                                    'Retake Initial Assessment',
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
                        title: 'Clinical Philosophy',
                        body:
                            'The program favors symptom response, movement quality, range of motion, strength symmetry, balance, hop testing, restrictions, graft considerations, and PT clearance over calendar time alone.',
                      ),
                      _section(
                        context,
                        icon: Icons.science_outlined,
                        title: 'Evidence-Based Rehabilitation',
                        body:
                            'Exercise choices are structured around controlled loading, progressive strength, neuromuscular control, and late-stage return-to-sport criteria. The app records feedback so future sessions can recommend regression, maintenance, or progression.',
                      ),
                      _section(
                        context,
                        icon: Icons.rule_outlined,
                        title: 'Criteria-Based Progression',
                        body:
                            'Advanced drills remain locked until pain, swelling, ROM, gait, strength symmetry, balance symmetry, hop symmetry, running tolerance, restrictions, and PT clearance meet the criteria for that drill.',
                      ),
                      _section(
                        context,
                        icon: Icons.medical_information_outlined,
                        title: 'Medical Disclaimer',
                        body:
                            'This app is educational and supportive. It does not diagnose, prescribe treatment, replace clinical care, or override surgeon or physical therapist instructions.',
                        accent: AppTheme.softRed,
                      ),
                      _graftSection(context),
                      _section(
                        context,
                        icon: Icons.menu_book_outlined,
                        title: 'Educational Information',
                        body:
                            'Patients can review why certain drills are locked, what criteria matter, and how symptoms after exercise should guide the next session.',
                      ),
                      _section(
                        context,
                        icon: Icons.source_outlined,
                        title: 'Protocol Sources',
                        body:
                            'Criteria and exercise gates are modeled from Mass General Brigham ACL reconstruction rehab guidance, Ohio State Sports Medicine ACL criteria, Aspetar ACLR return-to-running/return-to-sport guidance, and University of Delaware criteria-based ACL practice guidelines.',
                      ),
                      _section(
                        context,
                        icon: Icons.auto_stories_outlined,
                        title: 'Future References Placeholder',
                        body:
                            'The architecture is ready for authentication, cloud sync, wearable integration, AI recommendations, PT portals, push notifications, telehealth, analytics, PDF reports, and multi-language support.',
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
        title: const Text('Retake initial assessment?'),
        content: const Text(
          'You will go through onboarding again. Your session logs, milestone check-ins, and exercise history will be kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    HapticFeedback.mediumImpact();
    await ref.read(appControllerProvider.notifier).retakeInitialAssessment();
    if (context.mounted) {
      context.go(AppRoutes.onboarding);
    }
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
