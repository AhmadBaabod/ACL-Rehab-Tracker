import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/rehab_phase_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({this.initialAssessment, super.key});

  final Assessment? initialAssessment;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _totalSteps = 6;

  int step = 0;
  DateTime? surgeryDate;
  GraftType? graftType;
  int pain = 3;
  Swelling swelling = Swelling.mild;
  bool canStraighten = false;
  bool canBend = false;
  WeightBearing weightBearing = WeightBearing.partial;
  WalkingQuality walkingQuality = WalkingQuality.slightLimp;
  bool instability = false;
  bool locking = false;
  bool givingWay = false;
  bool straightLegRaiseNoLag = false;
  bool strongQuadSet = false;
  bool noPainOrSwellingAfterExercise = false;
  bool flexionNearOtherSide = false;
  bool singleLegSquatTenReps = false;
  bool dropJumpGoodControl = false;
  bool completedJogRunProgram = false;
  bool painFreeLoadingActivities = false;
  bool painFreeRepeatedSingleLegHops = false;
  int quadStrengthSymmetry = 0;
  int hamstringStrengthSymmetry = 0;
  int gluteStrengthSymmetry = 0;
  int balanceSymmetry = 0;
  int hopTestSymmetry = 0;
  int koosSportsScore = 0;
  int ikdcScore = 0;
  int aclRsiScore = 0;
  bool ptClearedForRunning = false;
  bool mdClearedForSport = false;
  List<String> restrictions = const ['No Running'];
  final notesController = TextEditingController();

  Assessment? get draftAssessment {
    final selectedSurgeryDate = surgeryDate;
    if (selectedSurgeryDate == null) {
      return null;
    }

    return Assessment(
      surgeryDate: selectedSurgeryDate,
      graftType: graftType ?? GraftType.hamstring,
      pain: pain,
      swelling: swelling,
      canStraighten: canStraighten,
      canBend: canBend,
      weightBearing: weightBearing,
      walkingQuality: walkingQuality,
      instability: instability,
      locking: locking,
      givingWay: givingWay,
      restrictions: restrictions,
      notes: notesController.text,
      protocolReadiness: ProtocolReadiness(
        readinessCompleted: true,
        straightLegRaiseNoLag: straightLegRaiseNoLag,
        strongQuadSet: strongQuadSet,
        noPainOrSwellingAfterExercise: noPainOrSwellingAfterExercise,
        flexionNearOtherSide: flexionNearOtherSide,
        singleLegSquatTenReps: singleLegSquatTenReps,
        dropJumpGoodControl: dropJumpGoodControl,
        completedJogRunProgram: completedJogRunProgram,
        painFreeLoadingActivities: painFreeLoadingActivities,
        painFreeRepeatedSingleLegHops: painFreeRepeatedSingleLegHops,
        quadStrengthSymmetry: quadStrengthSymmetry,
        hamstringStrengthSymmetry: hamstringStrengthSymmetry,
        gluteStrengthSymmetry: gluteStrengthSymmetry,
        balanceSymmetry: balanceSymmetry,
        hopTestSymmetry: hopTestSymmetry,
        koosSportsScore: koosSportsScore,
        ikdcScore: ikdcScore,
        aclRsiScore: aclRsiScore,
        ptClearedForRunning: ptClearedForRunning,
        mdClearedForSport: mdClearedForSport,
      ),
    );
  }

  PhaseEvaluation? get currentEvaluation {
    final assessment = draftAssessment;
    return assessment == null ? null : evaluateRehabPhase(assessment);
  }

  @override
  void initState() {
    super.initState();
    final initialAssessment = widget.initialAssessment;
    if (initialAssessment == null) {
      return;
    }

    surgeryDate = initialAssessment.surgeryDate;
    graftType = initialAssessment.graftType;
    pain = initialAssessment.pain;
    swelling = initialAssessment.swelling;
    canStraighten = initialAssessment.canStraighten;
    canBend = initialAssessment.canBend;
    weightBearing = initialAssessment.weightBearing;
    walkingQuality = initialAssessment.walkingQuality;
    instability = initialAssessment.instability;
    locking = initialAssessment.locking;
    givingWay = initialAssessment.givingWay;
    final readiness = initialAssessment.protocolReadiness;
    straightLegRaiseNoLag = readiness.straightLegRaiseNoLag;
    strongQuadSet = readiness.strongQuadSet;
    noPainOrSwellingAfterExercise = readiness.noPainOrSwellingAfterExercise;
    flexionNearOtherSide = readiness.flexionNearOtherSide;
    singleLegSquatTenReps = readiness.singleLegSquatTenReps;
    dropJumpGoodControl = readiness.dropJumpGoodControl;
    completedJogRunProgram = readiness.completedJogRunProgram;
    painFreeLoadingActivities = readiness.painFreeLoadingActivities;
    painFreeRepeatedSingleLegHops = readiness.painFreeRepeatedSingleLegHops;
    quadStrengthSymmetry = readiness.quadStrengthSymmetry;
    hamstringStrengthSymmetry = readiness.hamstringStrengthSymmetry;
    gluteStrengthSymmetry = readiness.gluteStrengthSymmetry;
    balanceSymmetry = readiness.balanceSymmetry;
    hopTestSymmetry = readiness.hopTestSymmetry;
    koosSportsScore = readiness.koosSportsScore;
    ikdcScore = readiness.ikdcScore;
    aclRsiScore = readiness.aclRsiScore;
    ptClearedForRunning = readiness.ptClearedForRunning;
    mdClearedForSport = readiness.mdClearedForSport;
    restrictions = [...initialAssessment.restrictions];
    notesController.text = initialAssessment.notes;
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = (step + 1) / _totalSteps;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessment'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${step + 1}/$_totalSteps',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.horizontalPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _stepTitle(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _stepDescription(),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 16),
                      const ClinicalDisclaimerBanner(),
                      const SizedBox(height: 18),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          child: KeyedSubtree(
                            key: ValueKey(step),
                            child: _buildStepContent(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (step > 0)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => step--);
                                },
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Back'),
                              ),
                            ),
                          if (step > 0) const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _handleNext,
                              icon: Icon(
                                step == _totalSteps - 1
                                    ? Icons.check_circle_outline
                                    : Icons.arrow_forward,
                              ),
                              label: Text(
                                step == _totalSteps - 1 ? 'Finish' : 'Next',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (step) {
      case 0:
        return _buildDateStep();
      case 1:
        return _buildGraftStep();
      case 2:
        return _buildSymptomsStep();
      case 3:
        return _buildProtocolReadinessStep();
      case 4:
        return _buildRestrictionsStep();
      case 5:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDateStep() {
    final selectedSurgeryDate = surgeryDate;
    final weeks = selectedSurgeryDate == null
        ? null
        : DateTime.now().difference(selectedSurgeryDate).inDays <= 0
        ? 0
        : (DateTime.now().difference(selectedSurgeryDate).inDays / 7).floor();

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Surgery Date',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Choose your ACL reconstruction surgery date. The app uses this as context, but phase progression still depends on symptoms and criteria.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickSurgeryDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    selectedSurgeryDate == null
                        ? 'Select surgery date'
                        : _formatDate(selectedSurgeryDate),
                  ),
                ),
                if (weeks != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'You are $weeks weeks post-op',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGraftStep() {
    return ListView.separated(
      itemCount: GraftType.values.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final type = GraftType.values[index];
        final selected = graftType == type;
        final scheme = Theme.of(context).colorScheme;

        return Semantics(
          button: true,
          selected: selected,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => graftType = type);
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              decoration: BoxDecoration(
                color: selected ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: selected ? scheme.primary : scheme.outline,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          type.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    type.educationTitle,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ...type.educationPoints.map(
                    (point) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('- '),
                          Expanded(child: Text(point)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSymptomsStep() {
    return ListView(
      children: [
        _buildSliderCard(
          'Pain',
          pain.toDouble(),
          0,
          10,
          (value) => setState(() => pain = value.round()),
        ),
        const SizedBox(height: 12),
        _buildChoiceCard<Swelling>(
          title: 'Swelling',
          value: swelling,
          options: Swelling.values,
          onChanged: (value) => setState(() => swelling = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Can fully straighten knee?',
          subtitle: 'Full extension is one of the earliest priority criteria.',
          value: canStraighten,
          onChanged: (value) => setState(() => canStraighten = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Can fully bend knee?',
          subtitle: 'Bending should be functional and not forceful.',
          value: canBend,
          onChanged: (value) => setState(() => canBend = value),
        ),
        const SizedBox(height: 12),
        _buildChoiceCard<WeightBearing>(
          title: 'Weight Bearing',
          value: weightBearing,
          options: WeightBearing.values,
          onChanged: (value) => setState(() => weightBearing = value),
        ),
        const SizedBox(height: 12),
        _buildChoiceCard<WalkingQuality>(
          title: 'Walking Quality',
          value: walkingQuality,
          options: WalkingQuality.values,
          onChanged: (value) => setState(() => walkingQuality = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Instability',
          subtitle: 'The knee feels unstable or unreliable.',
          value: instability,
          onChanged: (value) => setState(() => instability = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Locking',
          subtitle: 'The knee gets stuck or cannot move smoothly.',
          value: locking,
          onChanged: (value) => setState(() => locking = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Giving Way',
          subtitle: 'The knee buckles or gives way during activity.',
          value: givingWay,
          onChanged: (value) => setState(() => givingWay = value),
        ),
      ],
    );
  }

  Widget _buildProtocolReadinessStep() {
    return ListView(
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Protocol Readiness',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Only mark an item if it has already been measured, cleared, or practiced safely with your rehab team. Do not perform a new hop, jump, or running test just to answer this screen.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Straight leg raise without lag?',
          subtitle:
              'Used in early protocols before brace/crutch progression and higher quad loading.',
          value: straightLegRaiseNoLag,
          onChanged: (value) => setState(() => straightLegRaiseNoLag = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Strong quad set?',
          subtitle:
              'You can visibly tighten the thigh and control full active knee extension.',
          value: strongQuadSet,
          onChanged: (value) => setState(() => strongQuadSet = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'No pain or swelling increase after exercise?',
          subtitle:
              'Protocols commonly require no reactive pain/effusion before progression.',
          value: noPainOrSwellingAfterExercise,
          onChanged: (value) =>
              setState(() => noPainOrSwellingAfterExercise = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Knee bending near the other side?',
          subtitle:
              'Think within about 10 degrees, or roughly 95% of the other knee if measured.',
          value: flexionNearOtherSide,
          onChanged: (value) => setState(() => flexionNearOtherSide = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: '10 controlled single-leg squats or heel taps?',
          subtitle:
              'Good mechanics through about 60 degrees, without knee collapse or compensation.',
          value: singleLegSquatTenReps,
          onChanged: (value) => setState(() => singleLegSquatTenReps = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Good landing control on hop-down or drop-jump?',
          subtitle:
              'Only answer yes if this has already been assessed safely in rehab.',
          value: dropJumpGoodControl,
          onChanged: (value) => setState(() => dropJumpGoodControl = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Pain-free repeated single-leg hops?',
          subtitle:
              'Used as a return-to-running criterion in modern ACL guidance.',
          value: painFreeRepeatedSingleLegHops,
          onChanged: (value) =>
              setState(() => painFreeRepeatedSingleLegHops = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Pain-free loading activities?',
          subtitle:
              'Examples already cleared in rehab: squats, lunges, step-downs, or plyometric prep.',
          value: painFreeLoadingActivities,
          onChanged: (value) =>
              setState(() => painFreeLoadingActivities = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Completed a walk/jog progression without symptoms?',
          subtitle:
              'No pain or swelling during or after the running progression.',
          value: completedJogRunProgram,
          onChanged: (value) => setState(() => completedJogRunProgram = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'PT cleared running?',
          subtitle: 'Required before the app unlocks running-based drills.',
          value: ptClearedForRunning,
          onChanged: (value) => setState(() => ptClearedForRunning = value),
        ),
        const SizedBox(height: 12),
        _switchCard(
          title: 'Physician cleared sport progression?',
          subtitle:
              'Required before unrestricted return-to-sport drills unlock.',
          value: mdClearedForSport,
          onChanged: (value) => setState(() => mdClearedForSport = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'Quad strength symmetry',
          value: quadStrengthSymmetry,
          max: 100,
          suffix: '%',
          subtitle: 'Use 0 if not measured.',
          onChanged: (value) => setState(() => quadStrengthSymmetry = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'Hamstring strength symmetry',
          value: hamstringStrengthSymmetry,
          max: 100,
          suffix: '%',
          subtitle: 'Use 0 if not measured.',
          onChanged: (value) =>
              setState(() => hamstringStrengthSymmetry = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'Hip/glute strength symmetry',
          value: gluteStrengthSymmetry,
          max: 100,
          suffix: '%',
          subtitle: 'Use 0 if not measured.',
          onChanged: (value) => setState(() => gluteStrengthSymmetry = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'Balance symmetry',
          value: balanceSymmetry,
          max: 100,
          suffix: '%',
          subtitle: 'Use 0 if not measured.',
          onChanged: (value) => setState(() => balanceSymmetry = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'Hop test symmetry',
          value: hopTestSymmetry,
          max: 100,
          suffix: '%',
          subtitle: 'Use 0 if not measured.',
          onChanged: (value) => setState(() => hopTestSymmetry = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'KOOS-Sports score',
          value: koosSportsScore,
          max: 100,
          suffix: '',
          subtitle: 'Optional patient-reported outcome; use 0 if unknown.',
          onChanged: (value) => setState(() => koosSportsScore = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'IKDC score',
          value: ikdcScore,
          max: 100,
          suffix: '',
          subtitle: 'Optional patient-reported outcome; use 0 if unknown.',
          onChanged: (value) => setState(() => ikdcScore = value),
        ),
        const SizedBox(height: 12),
        _buildNumberSliderCard(
          title: 'ACL-RSI confidence score',
          value: aclRsiScore,
          max: 100,
          suffix: '',
          subtitle: 'Optional psychological readiness score; use 0 if unknown.',
          onChanged: (value) => setState(() => aclRsiScore = value),
        ),
      ],
    );
  }

  Widget _buildRestrictionsStep() {
    final restrictionsList = [
      'No Running',
      'Brace Required',
      'No Deep Squats',
      'No Open Chain Extension',
    ];

    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Restrictions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Add restrictions from your surgeon or physical therapist. These can block exercises that are not appropriate yet.',
                ),
                const SizedBox(height: 8),
                ...restrictionsList.map((item) {
                  final selected = restrictions.contains(item);
                  return CheckboxListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item),
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          restrictions = {...restrictions, item}.toList();
                        } else {
                          restrictions = restrictions
                              .where((entry) => entry != item)
                              .toList();
                        }
                      });
                    },
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: notesController,
          maxLines: 4,
          textInputAction: TextInputAction.newline,
          decoration: const InputDecoration(
            labelText: 'Custom restrictions',
            hintText: 'Add notes from your clinical team',
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final assessment = draftAssessment;
    final evaluation = currentEvaluation;

    return ListView(
      children: [
        if (evaluation != null)
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Suggested Rehab Phase',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    evaluation.phase.label,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  RehabPhaseTimeline(
                    phase: evaluation.phase,
                    progress: evaluation.progress,
                  ),
                ],
              ),
            ),
          ),
        if (evaluation != null && evaluation.blockers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.lock_outline,
            title: 'Why progression is limited',
            items: evaluation.blockers,
            color: AppTheme.amber,
          ),
        ],
        if (evaluation != null && evaluation.safetyFlags.isNotEmpty) ...[
          const SizedBox(height: 12),
          _infoCard(
            icon: Icons.medical_information_outlined,
            title: 'Clinical review flags',
            items: evaluation.safetyFlags,
            color: AppTheme.softRed,
          ),
        ],
        const SizedBox(height: 12),
        _summaryCard(
          title: 'Assessment Summary',
          rows: [
            MapEntry(
              'Surgery date',
              assessment == null
                  ? 'Not set'
                  : _formatDate(assessment.surgeryDate),
            ),
            MapEntry(
              'Week',
              assessment == null
                  ? 'Not set'
                  : '${assessment.weeksPostOp} weeks post-op',
            ),
            MapEntry('Graft', graftType?.label ?? 'Not set'),
            MapEntry('Pain', '$pain/10'),
            MapEntry('Swelling', swelling.label),
            MapEntry(
              'ROM',
              '${canStraighten ? 'Full extension' : 'Extension limited'}, ${canBend ? 'functional flexion' : 'flexion limited'}',
            ),
            MapEntry('Weight bearing', weightBearing.label),
            MapEntry('Walking', walkingQuality.label),
            MapEntry(
              'Early criteria',
              '${straightLegRaiseNoLag ? 'SLR no lag' : 'SLR not confirmed'}, ${strongQuadSet ? 'strong quad set' : 'quad set not confirmed'}',
            ),
            MapEntry(
              'Loading response',
              noPainOrSwellingAfterExercise
                  ? 'No pain/swelling increase'
                  : 'Not confirmed',
            ),
            MapEntry(
              'Control criteria',
              '${singleLegSquatTenReps ? 'single-leg squat/heel tap' : 'squat control not confirmed'}, ${dropJumpGoodControl ? 'landing control' : 'landing not confirmed'}',
            ),
            MapEntry(
              'Strength symmetry',
              'Quad $quadStrengthSymmetry%, hamstring $hamstringStrengthSymmetry%, hip $gluteStrengthSymmetry%',
            ),
            MapEntry(
              'Balance/Hop',
              'Balance $balanceSymmetry%, hop $hopTestSymmetry%',
            ),
            MapEntry(
              'Clearance',
              '${ptClearedForRunning ? 'PT running cleared' : 'running not cleared'}, ${mdClearedForSport ? 'sport cleared' : 'sport not cleared'}',
            ),
            MapEntry(
              'Restrictions',
              restrictions.isEmpty ? 'None listed' : restrictions.join(', '),
            ),
            MapEntry(
              'Notes',
              notesController.text.trim().isEmpty
                  ? 'None'
                  : notesController.text.trim(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required String title,
    required List<MapEntry<String, String>> rows,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        row.key,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
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

  Widget _infoCard({
    required IconData icon,
    required String title,
    required List<String> items,
    required Color color,
  }) {
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
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('- '),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderCard(
    String title,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${value.round()}/10',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: 10,
              label: value.round().toString(),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumberSliderCard({
    required String title,
    required int value,
    required int max,
    required ValueChanged<int> onChanged,
    String suffix = '',
    String subtitle = '',
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '$value$suffix',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Slider(
              value: value.toDouble(),
              min: 0,
              max: max.toDouble(),
              divisions: max,
              label: '$value$suffix',
              onChanged: (next) => onChanged(next.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceCard<T>({
    required String title,
    required T value,
    required List<T> options,
    required ValueChanged<T> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final selected = value == option;
                return ChoiceChip(
                  label: Text(_optionLabel(option)),
                  selected: selected,
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    onChanged(option);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchCard({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Card(
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppConstants.cardPadding,
          vertical: 8,
        ),
        title: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        value: value,
        onChanged: (next) {
          HapticFeedback.selectionClick();
          onChanged(next);
        },
      ),
    );
  }

  String _stepTitle() {
    switch (step) {
      case 0:
        return 'Surgery Timeline';
      case 1:
        return 'Graft Type';
      case 2:
        return 'Current Symptoms';
      case 3:
        return 'Protocol Readiness';
      case 4:
        return 'Restrictions';
      case 5:
        return 'Review';
      default:
        return 'Assessment';
    }
  }

  String _stepDescription() {
    switch (step) {
      case 0:
        return 'Set your surgery date to calculate weeks post-op.';
      case 1:
        return 'Choose the graft type so progression can respect graft-specific considerations.';
      case 2:
        return 'Share pain, swelling, range of motion, walking, and safety symptoms.';
      case 3:
        return 'Answer criteria used in modern ACL rehab protocols, using PT-measured values when available.';
      case 4:
        return 'Record clinical restrictions that should block unsafe exercise choices.';
      case 5:
        return 'Review the criteria-based phase assignment before starting.';
      default:
        return '';
    }
  }

  Future<void> _pickSurgeryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: surgeryDate ?? now,
      firstDate: DateTime(2015),
      lastDate: now,
      helpText: 'Select ACL surgery date',
    );
    if (picked != null) {
      HapticFeedback.selectionClick();
      setState(() => surgeryDate = picked);
    }
  }

  Future<void> _handleNext() async {
    if (surgeryDate == null && step == 0) {
      _showMessage('Please select your surgery date to continue.');
      return;
    }
    if (graftType == null && step == 1) {
      _showMessage('Please choose a graft type to continue.');
      return;
    }

    if (step == _totalSteps - 1) {
      final assessment = draftAssessment;
      if (assessment == null) {
        _showMessage('Please complete the assessment before continuing.');
        return;
      }

      HapticFeedback.mediumImpact();
      await ref
          .read(appControllerProvider.notifier)
          .completeOnboarding(assessment);
      if (!mounted) return;
      context.go(AppRoutes.dashboard);
      return;
    }

    HapticFeedback.selectionClick();
    setState(() => step++);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _optionLabel(Object? option) {
    if (option is Swelling) {
      return option.label;
    }
    if (option is WeightBearing) {
      return option.label;
    }
    if (option is WalkingQuality) {
      return option.label;
    }
    return option.toString();
  }
}
