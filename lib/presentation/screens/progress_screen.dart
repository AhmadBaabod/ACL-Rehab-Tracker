import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/metric_card.dart';
import 'package:acl_rehab/presentation/widgets/section_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return appStateAsync.when(
      data: (appState) {
        final assessment = appState.assessment;
        if (assessment == null) {
          return const Scaffold(
            body: Center(child: Text('Complete onboarding to track progress.')),
          );
        }

        final latest = appState.latestMilestone;
        final evaluation = evaluateRehabPhase(assessment, milestone: latest);
        final checkIns = [...appState.activeMilestoneCheckIns]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        final latestPain = latest?.pain ?? assessment.pain;
        final latestSwelling = latest?.swelling ?? assessment.swelling;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppConstants.horizontalPadding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ProgressHeader(
                        onCheckIn: () =>
                            _showCheckInSheet(context, ref, assessment, latest),
                      ),
                      const SizedBox(height: 16),
                      const ClinicalDisclaimerBanner(),
                      const SizedBox(height: AppConstants.sectionGap),
                      GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 230,
                              mainAxisExtent: 148,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                            ),
                        children: [
                          MetricCard(
                            title: 'Current Phase',
                            value: evaluation.phase.shortLabel,
                            subtitle: evaluation.phase.label,
                            icon: Icons.timeline,
                          ),
                          MetricCard(
                            title: 'Pain',
                            value: '$latestPain/10',
                            subtitle: latestPain <= 2
                                ? 'meets quiet-knee goal'
                                : 'needs monitoring',
                            icon: Icons.show_chart,
                            color: latestPain <= 2
                                ? AppTheme.teal
                                : AppTheme.amber,
                          ),
                          MetricCard(
                            title: 'Swelling',
                            value: latestSwelling.label,
                            subtitle: latestSwelling == Swelling.none
                                ? 'quiet knee'
                                : 'limit progression',
                            icon: Icons.water_drop_outlined,
                            color: latestSwelling == Swelling.none
                                ? AppTheme.teal
                                : AppTheme.amber,
                          ),
                          MetricCard(
                            title: 'Sessions',
                            value: '${appState.sessionLogs.length}',
                            subtitle: 'exercise logs',
                            icon: Icons.task_alt,
                            color: AppTheme.mintGreen,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppConstants.sectionGap),
                      SectionHeader(title: 'Charts'),
                      const SizedBox(height: 10),
                      _TrendCard(
                        title: 'Pain Trend',
                        icon: Icons.trending_down,
                        values: checkIns
                            .map((item) => item.pain)
                            .toList()
                            .reversed
                            .toList(),
                        maxValue: 10,
                        emptyValue: assessment.pain,
                        targetText: 'Target: 0-2/10',
                        color: AppTheme.teal,
                      ),
                      const SizedBox(height: 10),
                      _TrendCard(
                        title: 'ROM Trend',
                        icon: Icons.straighten,
                        values: checkIns
                            .map(
                              (item) =>
                                  item.hasFullExtension &&
                                      item.hasFunctionalFlexion
                                  ? 100
                                  : item.hasFullExtension
                                  ? 60
                                  : 30,
                            )
                            .toList()
                            .reversed
                            .toList(),
                        maxValue: 100,
                        emptyValue: assessment.hasFullRom ? 100 : 40,
                        targetText:
                            'Target: full extension + functional flexion',
                        color: AppTheme.softBlue,
                      ),
                      const SizedBox(height: 10),
                      _TrendCard(
                        title: 'Strength Trend',
                        icon: Icons.fitness_center,
                        values: checkIns
                            .map((item) => item.quadStrengthSymmetry)
                            .toList()
                            .reversed
                            .toList(),
                        maxValue: 100,
                        emptyValue: 0,
                        targetText: 'Target: 90%+ symmetry for return drills',
                        color: AppTheme.mintGreen,
                      ),
                      const SizedBox(height: 10),
                      _TrendCard(
                        title: 'Balance & Hop Trend',
                        icon: Icons.balance,
                        values: checkIns
                            .map(
                              (item) =>
                                  ((item.balanceSymmetry +
                                              item.hopTestSymmetry) /
                                          2)
                                      .round(),
                            )
                            .toList()
                            .reversed
                            .toList(),
                        maxValue: 100,
                        emptyValue: 0,
                        targetText: 'Target: 90%+ symmetry',
                        color: AppTheme.teal,
                      ),
                      const SizedBox(height: AppConstants.sectionGap),
                      SectionHeader(title: 'Milestones'),
                      const SizedBox(height: 10),
                      if (checkIns.isEmpty)
                        const _EmptyMilestones()
                      else
                        ...checkIns.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _MilestoneTile(checkIn: item),
                          ),
                        ),
                      const SizedBox(height: AppConstants.sectionGap),
                      SectionHeader(title: 'Reports'),
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
                                'Weekly Report',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${appState.sessionLogs.length} exercise logs and ${checkIns.length} milestone check-ins recorded.',
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Monthly Report',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'PDF export and clinician sharing are ready to add on top of this local history model.',
                              ),
                            ],
                          ),
                        ),
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
        body: Center(child: Text('Unable to load progress: $error')),
      ),
    );
  }

  Future<void> _showCheckInSheet(
    BuildContext context,
    WidgetRef ref,
    Assessment assessment,
    MilestoneCheckIn? latest,
  ) async {
    final checkIn = await showModalBottomSheet<MilestoneCheckIn>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) =>
          _MilestoneCheckInSheet(assessment: assessment, latest: latest),
    );

    if (checkIn != null) {
      HapticFeedback.mediumImpact();
      await ref
          .read(appControllerProvider.notifier)
          .addMilestoneCheckIn(checkIn);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Check-in saved. Your phase and session plan were recalculated.',
          ),
          action: SnackBarAction(
            label: 'Session',
            onPressed: () =>
                ref.read(appControllerProvider.notifier).updateSelectedIndex(1),
          ),
        ),
      );
    }
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.onCheckIn});

  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Progress',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Milestones recalculate your phase every 2-4 weeks.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final button = FilledButton.icon(
      onPressed: onCheckIn,
      icon: const Icon(Icons.add_chart),
      label: const Text('Check-in'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: button),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: title),
            const SizedBox(width: 12),
            button,
          ],
        );
      },
    );
  }
}

class _TrendCard extends StatelessWidget {
  const _TrendCard({
    required this.title,
    required this.icon,
    required this.values,
    required this.maxValue,
    required this.emptyValue,
    required this.targetText,
    required this.color,
  });

  final String title;
  final IconData icon;
  final List<int> values;
  final int maxValue;
  final int emptyValue;
  final String targetText;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final displayValues = values.isEmpty
        ? [emptyValue]
        : values.take(8).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(targetText, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 16),
            SizedBox(
              height: 70,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: displayValues.map((value) {
                  final percent = maxValue == 0
                      ? 0.0
                      : (value / maxValue).clamp(0.0, 1.0);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 520),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0, end: percent),
                        builder: (context, animated, child) {
                          return FractionallySizedBox(
                            heightFactor: animated,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              constraints: const BoxConstraints(minHeight: 8),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.78),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({required this.checkIn});

  final MilestoneCheckIn checkIn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.fact_check_outlined),
        title: Text(
          _formatDate(checkIn.createdAt),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          'Pain ${checkIn.pain}/10 - ${checkIn.swelling.label} swelling - confidence ${checkIn.confidence}/10',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          _row('Walking', checkIn.walkingQuality.label),
          if (checkIn.weightBearing != null)
            _row('Weight bearing', checkIn.weightBearing!.label),
          _row('Running tolerance', checkIn.canRun ? 'Yes' : 'No'),
          _row(
            'ROM',
            '${checkIn.hasFullExtension ? 'Full extension' : 'Extension limited'}, ${checkIn.hasFunctionalFlexion ? 'functional flexion' : 'flexion limited'}',
          ),
          _row('Quad symmetry', '${checkIn.quadStrengthSymmetry}%'),
          if (checkIn.hamstringStrengthSymmetry != null)
            _row('Hamstring symmetry', '${checkIn.hamstringStrengthSymmetry}%'),
          if (checkIn.hipStrengthSymmetry != null)
            _row('Hip/glute symmetry', '${checkIn.hipStrengthSymmetry}%'),
          _row('Hop symmetry', '${checkIn.hopTestSymmetry}%'),
          _row('Balance symmetry', '${checkIn.balanceSymmetry}%'),
          if (checkIn.painFreeLoadingActivities != null)
            _row(
              'Pain-free loading',
              checkIn.painFreeLoadingActivities!
                  ? 'Confirmed'
                  : 'Not confirmed',
            ),
          if (checkIn.completedJogRunProgram != null)
            _row(
              'Walk/jog progression',
              checkIn.completedJogRunProgram! ? 'Completed' : 'Not completed',
            ),
          if (checkIn.ptClearanceForRunning != null)
            _row(
              'PT running clearance',
              checkIn.ptClearanceForRunning! ? 'Recorded' : 'Not recorded',
            ),
          _row(
            'PT sport clearance',
            checkIn.ptClearanceForSport ? 'Recorded' : 'Not recorded',
          ),
          if (checkIn.physicianClearanceForSport != null)
            _row(
              'Physician clearance',
              checkIn.physicianClearanceForSport! ? 'Recorded' : 'Not recorded',
            ),
          if (checkIn.notes.trim().isNotEmpty)
            _row('Notes', checkIn.notes.trim()),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _EmptyMilestones extends StatelessWidget {
  const _EmptyMilestones();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Row(
          children: [
            Icon(
              Icons.add_chart,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'No milestone check-ins yet. Add one to track pain, swelling, ROM, confidence, strength, hop, and balance symmetry.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MilestoneCheckInSheet extends StatefulWidget {
  const _MilestoneCheckInSheet({
    required this.assessment,
    required this.latest,
  });

  final Assessment assessment;
  final MilestoneCheckIn? latest;

  @override
  State<_MilestoneCheckInSheet> createState() => _MilestoneCheckInSheetState();
}

class _MilestoneCheckInSheetState extends State<_MilestoneCheckInSheet> {
  late int pain = widget.latest?.pain ?? widget.assessment.pain;
  late Swelling swelling =
      widget.latest?.swelling ?? widget.assessment.swelling;
  late WalkingQuality walkingQuality =
      widget.latest?.walkingQuality ?? widget.assessment.walkingQuality;
  late WeightBearing weightBearing =
      widget.latest?.weightBearing ?? widget.assessment.weightBearing;
  late bool canRun = widget.latest?.canRun ?? false;
  late bool hasFullExtension =
      widget.latest?.hasFullExtension ?? widget.assessment.canStraighten;
  late bool hasFunctionalFlexion =
      widget.latest?.hasFunctionalFlexion ?? widget.assessment.canBend;
  late int confidence = widget.latest?.confidence ?? 5;
  late int quadStrengthSymmetry = widget.latest?.quadStrengthSymmetry ?? 0;
  late int hamstringStrengthSymmetry =
      widget.latest?.hamstringStrengthSymmetry ??
      widget.assessment.protocolReadiness.hamstringStrengthSymmetry;
  late int hipStrengthSymmetry =
      widget.latest?.hipStrengthSymmetry ??
      widget.assessment.protocolReadiness.gluteStrengthSymmetry;
  late int hopTestSymmetry = widget.latest?.hopTestSymmetry ?? 0;
  late int balanceSymmetry = widget.latest?.balanceSymmetry ?? 0;
  late int koosSportsScore =
      widget.latest?.koosSportsScore ??
      widget.assessment.protocolReadiness.koosSportsScore;
  late int ikdcScore =
      widget.latest?.ikdcScore ?? widget.assessment.protocolReadiness.ikdcScore;
  late int aclRsiScore =
      widget.latest?.aclRsiScore ??
      widget.assessment.protocolReadiness.aclRsiScore;
  late bool painFreeLoadingActivities =
      widget.latest?.painFreeLoadingActivities ??
      widget.assessment.protocolReadiness.painFreeLoadingActivities;
  late bool painFreeRepeatedSingleLegHops =
      widget.latest?.painFreeRepeatedSingleLegHops ??
      widget.assessment.protocolReadiness.painFreeRepeatedSingleLegHops;
  late bool canPerformControlledSingleLegSquat =
      widget.latest?.canPerformControlledSingleLegSquat ??
      widget.assessment.protocolReadiness.singleLegSquatTenReps;
  late bool goodLandingControl =
      widget.latest?.goodLandingControl ??
      widget.assessment.protocolReadiness.dropJumpGoodControl;
  late bool completedJogRunProgram =
      widget.latest?.completedJogRunProgram ??
      widget.assessment.protocolReadiness.completedJogRunProgram;
  late bool ptClearanceForRunning =
      widget.latest?.ptClearanceForRunning ??
      widget.assessment.protocolReadiness.ptClearedForRunning;
  late bool ptClearanceForSport = widget.latest?.ptClearanceForSport ?? false;
  late bool physicianClearanceForSport =
      widget.latest?.physicianClearanceForSport ??
      widget.assessment.protocolReadiness.mdClearedForSport;
  final notesController = TextEditingController();

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Milestone Check-in',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter values measured or confirmed by your rehabilitation team.',
            ),
            const SizedBox(height: 8),
            Text(
              'Do not perform a new hop, jump, landing, or running test just to complete this check-in.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            _slider(
              'Pain',
              pain,
              0,
              10,
              (value) => setState(() => pain = value),
            ),
            _choice<Swelling>(
              'Swelling',
              swelling,
              Swelling.values,
              (value) => setState(() => swelling = value),
              (value) => value.label,
            ),
            _choice<WalkingQuality>(
              'Walking',
              walkingQuality,
              WalkingQuality.values,
              (value) => setState(() => walkingQuality = value),
              (value) => value.label,
            ),
            _choice<WeightBearing>(
              'Weight bearing',
              weightBearing,
              WeightBearing.values,
              (value) => setState(() => weightBearing = value),
              (value) => value.label,
            ),
            _switch(
              'Can run without symptoms?',
              canRun,
              (value) => setState(() => canRun = value),
            ),
            _switch(
              'Full knee extension?',
              hasFullExtension,
              (value) => setState(() => hasFullExtension = value),
            ),
            _switch(
              'Functional knee flexion?',
              hasFunctionalFlexion,
              (value) => setState(() => hasFunctionalFlexion = value),
            ),
            _slider(
              'Confidence',
              confidence,
              0,
              10,
              (value) => setState(() => confidence = value),
            ),
            _slider(
              'Quad strength symmetry',
              quadStrengthSymmetry,
              0,
              100,
              (value) => setState(() => quadStrengthSymmetry = value),
              suffix: '%',
            ),
            _slider(
              'Hamstring strength symmetry',
              hamstringStrengthSymmetry,
              0,
              100,
              (value) => setState(() => hamstringStrengthSymmetry = value),
              suffix: '%',
            ),
            _slider(
              'Hip/glute strength symmetry',
              hipStrengthSymmetry,
              0,
              100,
              (value) => setState(() => hipStrengthSymmetry = value),
              suffix: '%',
            ),
            _slider(
              'Hop test symmetry',
              hopTestSymmetry,
              0,
              100,
              (value) => setState(() => hopTestSymmetry = value),
              suffix: '%',
            ),
            _slider(
              'Balance symmetry',
              balanceSymmetry,
              0,
              100,
              (value) => setState(() => balanceSymmetry = value),
              suffix: '%',
            ),
            const SizedBox(height: 4),
            Text(
              'Movement readiness',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _switch(
              'Pain-free loading activities confirmed?',
              painFreeLoadingActivities,
              (value) => setState(() => painFreeLoadingActivities = value),
            ),
            _switch(
              'PT confirmed 10 controlled single-leg squats?',
              canPerformControlledSingleLegSquat,
              (value) =>
                  setState(() => canPerformControlledSingleLegSquat = value),
            ),
            _switch(
              'PT confirmed controlled landing mechanics?',
              goodLandingControl,
              (value) => setState(() => goodLandingControl = value),
            ),
            _switch(
              'Pain-free repeated single-leg hops confirmed?',
              painFreeRepeatedSingleLegHops,
              (value) => setState(() => painFreeRepeatedSingleLegHops = value),
            ),
            _switch(
              'Completed a walk/jog progression without symptoms?',
              completedJogRunProgram,
              (value) => setState(() => completedJogRunProgram = value),
            ),
            _switch(
              'PT clearance to start or progress running?',
              ptClearanceForRunning,
              (value) => setState(() => ptClearanceForRunning = value),
            ),
            const SizedBox(height: 4),
            Text(
              'Return-to-sport outcomes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            _slider(
              'KOOS-Sports score',
              koosSportsScore,
              0,
              100,
              (value) => setState(() => koosSportsScore = value),
              suffix: '%',
            ),
            _slider(
              'IKDC score',
              ikdcScore,
              0,
              100,
              (value) => setState(() => ikdcScore = value),
              suffix: '%',
            ),
            _slider(
              'ACL-RSI score',
              aclRsiScore,
              0,
              100,
              (value) => setState(() => aclRsiScore = value),
              suffix: '%',
            ),
            _switch(
              'PT clearance for sport drills?',
              ptClearanceForSport,
              (value) => setState(() => ptClearanceForSport = value),
            ),
            _switch(
              'Physician clearance for return to sport?',
              physicianClearanceForSport,
              (value) => setState(() => physicianClearanceForSport = value),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Optional notes from your check-in',
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop(
                    MilestoneCheckIn(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      createdAt: DateTime.now(),
                      pain: pain,
                      swelling: swelling,
                      walkingQuality: walkingQuality,
                      canRun: canRun,
                      weightBearing: weightBearing,
                      hasFullExtension: hasFullExtension,
                      hasFunctionalFlexion: hasFunctionalFlexion,
                      confidence: confidence,
                      quadStrengthSymmetry: quadStrengthSymmetry,
                      hamstringStrengthSymmetry: hamstringStrengthSymmetry,
                      hipStrengthSymmetry: hipStrengthSymmetry,
                      hopTestSymmetry: hopTestSymmetry,
                      balanceSymmetry: balanceSymmetry,
                      koosSportsScore: koosSportsScore,
                      ikdcScore: ikdcScore,
                      aclRsiScore: aclRsiScore,
                      painFreeLoadingActivities: painFreeLoadingActivities,
                      painFreeRepeatedSingleLegHops:
                          painFreeRepeatedSingleLegHops,
                      canPerformControlledSingleLegSquat:
                          canPerformControlledSingleLegSquat,
                      goodLandingControl: goodLandingControl,
                      completedJogRunProgram: completedJogRunProgram,
                      ptClearanceForRunning: ptClearanceForRunning,
                      ptClearanceForSport: ptClearanceForSport,
                      physicianClearanceForSport: physicianClearanceForSport,
                      notes: notesController.text,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Save Check-in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    int value,
    int min,
    int max,
    ValueChanged<int> onChanged, {
    String suffix = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              Text('$value$suffix'),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            label: '$value$suffix',
            onChanged: (next) => onChanged(next.round()),
          ),
        ],
      ),
    );
  }

  Widget _choice<T>(
    String title,
    T value,
    List<T> options,
    ValueChanged<T> onChanged,
    String Function(T value) labelBuilder,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              return ChoiceChip(
                label: Text(labelBuilder(option)),
                selected: option == value,
                onSelected: (_) => onChanged(option),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _switch(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      value: value,
      onChanged: onChanged,
    );
  }
}
