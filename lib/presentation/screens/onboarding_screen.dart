import 'package:acl_rehab/core/constants/app_constants.dart';
import 'package:acl_rehab/core/navigation/app_router.dart';
import 'package:acl_rehab/core/theme/app_theme.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/assessment_record.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/assessment_comparison.dart';
import 'package:acl_rehab/domain/services/assessment_consistency.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/widgets/clinical_disclaimer_banner.dart';
import 'package:acl_rehab/presentation/widgets/common.dart';
import 'package:acl_rehab/presentation/widgets/form_widgets.dart';
import 'package:acl_rehab/presentation/widgets/rehab_phase_timeline.dart';
import 'package:acl_rehab/presentation/widgets/training_setup_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum AssessmentMode { initial, retake, reassessment }

enum _Step { timeline, graft, symptoms, readiness, restrictions, setup, review }

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({
    this.mode = AssessmentMode.initial,
    this.initialAssessment,
    super.key,
  });

  final AssessmentMode mode;

  /// Answers to start from. When omitted in retake or reassessment mode, the
  /// current assessment (and latest check-in) is used.
  final Assessment? initialAssessment;

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _restrictionOptions = [
    'No Running',
    'Brace Required',
    'No Deep Squats',
    'No Open Chain Extension',
  ];

  late final List<_Step> _steps = widget.mode == AssessmentMode.reassessment
      ? const [
          _Step.symptoms,
          _Step.readiness,
          _Step.restrictions,
          _Step.setup,
          _Step.review,
        ]
      : _Step.values;

  int stepIndex = 0;
  bool _saving = false;
  bool _restrictionsTouched = false;
  AppState? _existing;

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
  int confidence = 5;
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
  List<String> restrictions = const [];
  TrainingProfile profile = const TrainingProfile();
  final notesController = TextEditingController();
  final sportController = TextEditingController();

  _Step get step => _steps[stepIndex];

  bool get _isLastStep => stepIndex == _steps.length - 1;

  int? get _weeksPostOp {
    final date = surgeryDate;
    if (date == null) return null;
    final days = DateTime.now().difference(date).inDays;
    return days <= 0 ? 0 : (days / 7).floor();
  }

  Assessment? get draftAssessment {
    final selectedSurgeryDate = surgeryDate;
    if (selectedSurgeryDate == null) return null;

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
      confidence: confidence,
      profile: profile.copyWith(sport: sportController.text.trim()),
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

  @override
  void initState() {
    super.initState();
    if (widget.mode != AssessmentMode.initial) {
      _existing = ref.read(appControllerProvider).value;
    }
    final start = widget.initialAssessment ?? _existing?.assessment;
    if (start != null) {
      _prefill(start);
      _restrictionsTouched = true;
    }
    if (widget.mode == AssessmentMode.reassessment) {
      _applyLatestCheckIn();
    }
  }

  void _prefill(Assessment assessment) {
    surgeryDate = assessment.surgeryDate;
    graftType = assessment.graftType;
    pain = assessment.pain;
    swelling = assessment.swelling;
    canStraighten = assessment.canStraighten;
    canBend = assessment.canBend;
    weightBearing = assessment.weightBearing;
    walkingQuality = assessment.walkingQuality;
    instability = assessment.instability;
    locking = assessment.locking;
    givingWay = assessment.givingWay;
    confidence = assessment.confidence;
    final readiness = assessment.protocolReadiness;
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
    restrictions = [...assessment.restrictions];
    notesController.text = assessment.notes;
    profile = assessment.profile.copyWith(isDefault: false);
    sportController.text = assessment.profile.sport;
  }

  /// Starts a reassessment from the latest known status, so only what has
  /// changed needs editing.
  void _applyLatestCheckIn() {
    final checkIn = _existing?.latestMilestone;
    if (checkIn == null) return;
    pain = checkIn.pain;
    swelling = checkIn.swelling;
    walkingQuality = checkIn.walkingQuality;
    weightBearing = checkIn.weightBearing ?? weightBearing;
    canStraighten = checkIn.hasFullExtension;
    canBend = checkIn.hasFunctionalFlexion;
    flexionNearOtherSide = checkIn.hasFunctionalFlexion || flexionNearOtherSide;
    confidence = checkIn.confidence;
    quadStrengthSymmetry = checkIn.quadStrengthSymmetry;
    hopTestSymmetry = checkIn.hopTestSymmetry;
    balanceSymmetry = checkIn.balanceSymmetry;
    hamstringStrengthSymmetry =
        checkIn.hamstringStrengthSymmetry ?? hamstringStrengthSymmetry;
    gluteStrengthSymmetry =
        checkIn.hipStrengthSymmetry ?? gluteStrengthSymmetry;
    koosSportsScore = checkIn.koosSportsScore ?? koosSportsScore;
    ikdcScore = checkIn.ikdcScore ?? ikdcScore;
    aclRsiScore = checkIn.aclRsiScore ?? aclRsiScore;
    painFreeLoadingActivities =
        checkIn.painFreeLoadingActivities ?? painFreeLoadingActivities;
    painFreeRepeatedSingleLegHops =
        checkIn.painFreeRepeatedSingleLegHops ?? painFreeRepeatedSingleLegHops;
    singleLegSquatTenReps =
        checkIn.canPerformControlledSingleLegSquat ?? singleLegSquatTenReps;
    dropJumpGoodControl = checkIn.goodLandingControl ?? dropJumpGoodControl;
    completedJogRunProgram =
        checkIn.completedJogRunProgram ?? completedJogRunProgram;
    ptClearedForRunning = checkIn.ptClearanceForRunning ?? ptClearedForRunning;
    mdClearedForSport = checkIn.physicianClearanceForSport ?? mdClearedForSport;
  }

  @override
  void dispose() {
    notesController.dispose();
    sportController.dispose();
    super.dispose();
  }

  String get _screenTitle {
    switch (widget.mode) {
      case AssessmentMode.initial:
        return 'Assessment';
      case AssessmentMode.retake:
        return 'Correct assessment';
      case AssessmentMode.reassessment:
        return 'Reassessment';
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (stepIndex + 1) / _steps.length;
    final canLeave = widget.mode != AssessmentMode.initial;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (stepIndex > 0) {
          setState(() => stepIndex--);
        } else if (canLeave) {
          _confirmLeave();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle),
          automaticallyImplyLeading: false,
          leading: canLeave
              ? IconButton(
                  tooltip: 'Close without saving',
                  icon: const Icon(Icons.close),
                  onPressed: _confirmLeave,
                )
              : null,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Semantics(
                  label: 'Step ${stepIndex + 1} of ${_steps.length}',
                  child: ExcludeSemantics(
                    child: Text(
                      '${stepIndex + 1}/${_steps.length}',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.horizontalPadding,
                  8,
                  AppConstants.horizontalPadding,
                  AppConstants.horizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(999),
                      semanticsLabel: 'Assessment progress',
                    ),
                    const SizedBox(height: 18),
                    Semantics(
                      header: true,
                      child: Text(
                        _stepTitle(step),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _stepDescription(step),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 240),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        child: KeyedSubtree(
                          key: ValueKey(step),
                          child: _buildStepContent(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (stepIndex > 0) ...[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      HapticFeedback.selectionClick();
                                      setState(() => stepIndex--);
                                    },
                              icon: const Icon(Icons.arrow_back),
                              label: const Text('Back'),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _handleNext,
                            icon: _saving
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isLastStep
                                        ? Icons.check_circle_outline
                                        : Icons.arrow_forward,
                                  ),
                            label: Text(_nextLabel),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _nextLabel {
    if (!_isLastStep) return 'Next';
    switch (widget.mode) {
      case AssessmentMode.initial:
        return 'Create my plan';
      case AssessmentMode.retake:
        return 'Save and rebuild plan';
      case AssessmentMode.reassessment:
        return 'Save and update plan';
    }
  }

  Widget _buildStepContent() {
    switch (step) {
      case _Step.timeline:
        return _buildDateStep();
      case _Step.graft:
        return _buildGraftStep();
      case _Step.symptoms:
        return _buildSymptomsStep();
      case _Step.readiness:
        return _buildReadinessStep();
      case _Step.restrictions:
        return _buildRestrictionsStep();
      case _Step.setup:
        return ListView(
          children: [
            TrainingSetupFields(
              profile: profile,
              sportController: sportController,
              onChanged: (next) => setState(() => profile = next),
            ),
          ],
        );
      case _Step.review:
        return _buildReviewStep();
    }
  }

  Widget _buildDateStep() {
    final weeks = _weeksPostOp;
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        const ClinicalDisclaimerBanner(),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.event_available_outlined, color: scheme.primary),
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
                const Text(
                  'Choose your ACL reconstruction surgery date. Time since surgery '
                  'is context; phase progression still depends on symptoms and criteria.',
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickSurgeryDate,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(
                    surgeryDate == null
                        ? 'Select surgery date'
                        : formatDate(surgeryDate!),
                  ),
                ),
                if (weeks != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'You are $weeks ${weeks == 1 ? 'week' : 'weeks'} post-op',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
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
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      itemCount: GraftType.values.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final type = GraftType.values[index];
        final selected = graftType == type;
        return Semantics(
          button: true,
          selected: selected,
          label: type.label,
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
                  width: selected ? 1.6 : 1,
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
                  const SizedBox(height: 8),
                  for (final point in type.educationPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 34),
                      child: Text(point),
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
        QuestionSection(
          title: 'Pain and swelling',
          children: [
            ScaleSliderCard(
              title: 'Pain right now',
              subtitle: 'Your typical knee pain today.',
              value: pain,
              lowLabel: '0 = no pain',
              highLabel: '10 = worst imaginable',
              onChanged: (value) => setState(() => pain = value),
            ),
            ChoiceCard<Swelling>(
              title: 'Swelling',
              value: swelling,
              options: Swelling.values,
              labelOf: (value) => value.label,
              helpOf: _swellingHelp,
              onChanged: (value) => setState(() => swelling = value),
            ),
          ],
        ),
        QuestionSection(
          title: 'Movement',
          children: [
            YesNoCard(
              title: 'Can you fully straighten the knee?',
              subtitle:
                  'The back of the knee rests flat, like the other side. '
                  'Full extension is the first priority.',
              value: canStraighten,
              onChanged: (value) => setState(() => canStraighten = value),
            ),
            YesNoCard(
              title: 'Can you bend the knee functionally?',
              subtitle: 'Enough for stairs and sitting, without forcing it.',
              value: canBend,
              onChanged: (value) => setState(() => canBend = value),
            ),
            ChoiceCard<WeightBearing>(
              title: 'Weight bearing',
              value: weightBearing,
              options: WeightBearing.values,
              labelOf: (value) => value.label,
              helpOf: _weightBearingHelp,
              onChanged: (value) => setState(() => weightBearing = value),
            ),
            ChoiceCard<WalkingQuality>(
              title: 'Walking',
              value: walkingQuality,
              options: WalkingQuality.values,
              labelOf: (value) => value.label,
              helpOf: _walkingHelp,
              onChanged: (value) => setState(() => walkingQuality = value),
            ),
          ],
        ),
        QuestionSection(
          title: 'Warning signs',
          subtitle:
              'Any of these pauses progression until reviewed by your team.',
          children: [
            YesNoCard(
              title: 'Instability',
              subtitle: 'The knee feels unstable or unreliable.',
              value: instability,
              onChanged: (value) => setState(() => instability = value),
            ),
            YesNoCard(
              title: 'Locking',
              subtitle: 'The knee gets stuck or cannot move smoothly.',
              value: locking,
              onChanged: (value) => setState(() => locking = value),
            ),
            YesNoCard(
              title: 'Giving Way',
              subtitle: 'The knee buckles or gives way during activity.',
              value: givingWay,
              onChanged: (value) => setState(() => givingWay = value),
            ),
          ],
        ),
        QuestionSection(
          title: 'Confidence',
          children: [
            ScaleSliderCard(
              title: 'Confidence in your knee',
              subtitle:
                  'Low confidence is common. It helps the plan choose '
                  'controlled variations first.',
              value: confidence,
              lowLabel: '0 = none',
              highLabel: '10 = complete',
              onChanged: (value) => setState(() => confidence = value),
            ),
          ],
        ),
      ],
    );
  }

  String _swellingHelp(Swelling value) {
    switch (value) {
      case Swelling.none:
        return 'The knee looks the same size as the other side.';
      case Swelling.mild:
        return 'Slight puffiness that does not limit movement.';
      case Swelling.moderate:
        return 'Clearly swollen; bending feels tight.';
      case Swelling.severe:
        return 'Very swollen, tense, or warm. Contact your team if this is new.';
    }
  }

  String _weightBearingHelp(WeightBearing value) {
    switch (value) {
      case WeightBearing.partial:
        return 'Some weight through the leg, usually with crutches.';
      case WeightBearing.full:
        return 'All your weight on the leg without crutches.';
      case WeightBearing.limited:
        return 'Little or no weight allowed, or too painful to load.';
    }
  }

  String _walkingHelp(WalkingQuality value) {
    switch (value) {
      case WalkingQuality.normal:
        return 'Even steps with no limp.';
      case WalkingQuality.slightLimp:
        return 'A small limp that others might notice.';
      case WalkingQuality.painful:
        return 'Walking is painful, even if it looks close to normal.';
      case WalkingQuality.antalgic:
        return 'A clear limp, shortening the step on the surgical leg.';
    }
  }

  Widget _buildReadinessStep() {
    final weeks = _weeksPostOp ?? 0;
    final laterAnswered =
        singleLegSquatTenReps ||
        dropJumpGoodControl ||
        painFreeLoadingActivities ||
        painFreeRepeatedSingleLegHops ||
        completedJogRunProgram ||
        ptClearedForRunning ||
        mdClearedForSport;
    final anyMeasured = [
      quadStrengthSymmetry,
      hamstringStrengthSymmetry,
      gluteStrengthSymmetry,
      balanceSymmetry,
      hopTestSymmetry,
      koosSportsScore,
      ikdcScore,
      aclRsiScore,
    ].any((value) => value > 0);

    return ListView(
      children: [
        Card(
          color: Theme.of(context).colorScheme.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Only mark an item if it has already been measured, cleared, '
                    'or practiced safely with your rehab team. Do not perform a new '
                    'hop, jump, or running test just to answer.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        QuestionSection(
          title: 'Early control',
          children: [
            YesNoCard(
              title: 'Straight leg raise without lag?',
              subtitle: 'The knee stays fully straight as you lift the leg.',
              value: straightLegRaiseNoLag,
              onChanged: (value) =>
                  setState(() => straightLegRaiseNoLag = value),
            ),
            YesNoCard(
              title: 'Strong quad set?',
              subtitle:
                  'You can visibly tighten the thigh and the kneecap glides up.',
              value: strongQuadSet,
              onChanged: (value) => setState(() => strongQuadSet = value),
            ),
            YesNoCard(
              title: 'No pain or swelling increase after exercise?',
              subtitle: 'Checked later that day and the next morning.',
              value: noPainOrSwellingAfterExercise,
              onChanged: (value) =>
                  setState(() => noPainOrSwellingAfterExercise = value),
            ),
            YesNoCard(
              title: 'Knee bending close to the other side?',
              subtitle:
                  'Within about 10 degrees, or roughly 95% of the other knee if measured.',
              value: flexionNearOtherSide,
              onChanged: (value) =>
                  setState(() => flexionNearOtherSide = value),
            ),
          ],
        ),
        _Collapsible(
          title: 'Later-stage criteria',
          subtitle: weeks < 10
              ? 'Usually relevant from about 3 months. Skip if not yet assessed.'
              : 'Loading, landing, running, and clearances.',
          initiallyExpanded: weeks >= 10 || laterAnswered,
          children: [
            YesNoCard(
              title: 'Pain-free loading activities?',
              subtitle:
                  'Squats, lunges, or step-downs already cleared in rehab, without pain.',
              value: painFreeLoadingActivities,
              onChanged: (value) =>
                  setState(() => painFreeLoadingActivities = value),
            ),
            YesNoCard(
              title: '10 controlled single-leg squats?',
              subtitle:
                  'To about 60 degrees without the knee collapsing inward.',
              value: singleLegSquatTenReps,
              onChanged: (value) =>
                  setState(() => singleLegSquatTenReps = value),
            ),
            YesNoCard(
              title: 'Good landing control?',
              subtitle: 'On a hop-down or drop-jump already assessed in rehab.',
              value: dropJumpGoodControl,
              onChanged: (value) => setState(() => dropJumpGoodControl = value),
            ),
            YesNoCard(
              title: 'Pain-free repeated single-leg hops?',
              value: painFreeRepeatedSingleLegHops,
              onChanged: (value) =>
                  setState(() => painFreeRepeatedSingleLegHops = value),
            ),
            YesNoCard(
              title: 'Completed a walk/jog progression without symptoms?',
              value: completedJogRunProgram,
              onChanged: (value) =>
                  setState(() => completedJogRunProgram = value),
            ),
            YesNoCard(
              title: 'PT cleared running?',
              subtitle: 'Required before running drills unlock.',
              value: ptClearedForRunning,
              onChanged: (value) => setState(() => ptClearedForRunning = value),
            ),
            YesNoCard(
              title: 'Physician cleared sport progression?',
              subtitle: 'Required before return-to-sport drills unlock.',
              value: mdClearedForSport,
              onChanged: (value) => setState(() => mdClearedForSport = value),
            ),
          ],
        ),
        _Collapsible(
          title: 'Measured results (optional)',
          subtitle:
              'Symmetry compares the surgical leg with the other leg. Leave '
              '"Not measured" if you have not been tested.',
          initiallyExpanded: anyMeasured,
          children: [
            MeasuredScoreCard(
              title: 'Quadriceps strength symmetry',
              value: quadStrengthSymmetry,
              onChanged: (value) =>
                  setState(() => quadStrengthSymmetry = value),
            ),
            MeasuredScoreCard(
              title: 'Hamstring strength symmetry',
              value: hamstringStrengthSymmetry,
              onChanged: (value) =>
                  setState(() => hamstringStrengthSymmetry = value),
            ),
            MeasuredScoreCard(
              title: 'Hip/glute strength symmetry',
              value: gluteStrengthSymmetry,
              onChanged: (value) =>
                  setState(() => gluteStrengthSymmetry = value),
            ),
            MeasuredScoreCard(
              title: 'Balance symmetry',
              value: balanceSymmetry,
              onChanged: (value) => setState(() => balanceSymmetry = value),
            ),
            MeasuredScoreCard(
              title: 'Hop test symmetry',
              value: hopTestSymmetry,
              onChanged: (value) => setState(() => hopTestSymmetry = value),
            ),
            MeasuredScoreCard(
              title: 'KOOS-Sports score',
              suffix: '',
              value: koosSportsScore,
              onChanged: (value) => setState(() => koosSportsScore = value),
            ),
            MeasuredScoreCard(
              title: 'IKDC score',
              suffix: '',
              value: ikdcScore,
              onChanged: (value) => setState(() => ikdcScore = value),
            ),
            MeasuredScoreCard(
              title: 'ACL-RSI confidence score',
              suffix: '',
              value: aclRsiScore,
              onChanged: (value) => setState(() => aclRsiScore = value),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRestrictionsStep() {
    final weeks = _weeksPostOp ?? 0;
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current restrictions',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add restrictions from your surgeon or physical therapist. '
                  'Restricted exercises are never included in your plan.',
                ),
                if (!_restrictionsTouched && weeks < 12) ...[
                  const SizedBox(height: 8),
                  Text(
                    '"No Running" is pre-selected because running is usually not '
                    'cleared before about 3 months.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                for (final item in _restrictionOptions)
                  CheckboxListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item),
                    value: restrictions.contains(item),
                    onChanged: (value) {
                      setState(() {
                        _restrictionsTouched = true;
                        restrictions = value == true
                            ? {...restrictions, item}.toList()
                            : restrictions
                                  .where((entry) => entry != item)
                                  .toList();
                      });
                    },
                  ),
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
            labelText: 'Other notes from your clinical team',
            hintText: 'For example: flexion limited to 90 degrees until week 6',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    final assessment = draftAssessment;
    if (assessment == null) {
      return const Center(child: Text('Add your surgery date to continue.'));
    }
    final existing = _existing;
    final evaluation = evaluateRehabPhase(assessment);
    final plan = PlanGenerator.generate(
      PlanGenerationInput(
        assessment: assessment,
        progressions: existing?.exerciseProgressions ?? const {},
        previousPlan: existing?.activePlan,
        trigger: widget.mode == AssessmentMode.reassessment
            ? PlanTrigger.reassessment
            : PlanTrigger.initial,
      ),
    );
    final issues = checkAssessmentConsistency(assessment);

    AssessmentComparison? comparison;
    final previous = existing?.assessment;
    if (widget.mode == AssessmentMode.reassessment && previous != null) {
      final milestone = existing!.latestMilestone;
      comparison = AssessmentComparison.compare(
        before: RehabStatus.from(previous, milestone: milestone),
        after: RehabStatus.from(assessment),
        previousPhase: evaluateRehabPhase(previous, milestone: milestone).phase,
        currentPhase: evaluation.phase,
        previousPlan: existing.activePlan,
        newPlan: plan,
      );
    }

    return ListView(
      children: [
        if (evaluation.safetyFlags.isNotEmpty) ...[
          InfoListCard(
            icon: Icons.medical_information_outlined,
            title: 'Please contact your clinical team',
            items: evaluation.safetyFlags,
            color: AppTheme.softRed,
          ),
          const SizedBox(height: 12),
        ],
        if (comparison != null) ...[
          _ChangesCard(comparison: comparison),
          const SizedBox(height: 12),
        ],
        _PlanPreviewCard(evaluation: evaluation, plan: plan),
        if (issues.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.rule_folder_outlined,
                        color: AppTheme.amber,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Double-check these answers',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (final issue in issues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(issue.message),
                          Text(
                            issue.resolution,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => _jumpTo(_Step.symptoms),
                        child: const Text('Edit symptoms'),
                      ),
                      TextButton(
                        onPressed: () => _jumpTo(_Step.readiness),
                        child: const Text('Edit readiness'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _summaryCard(assessment),
        if (step == _Step.review && widget.mode == AssessmentMode.initial) ...[
          const SizedBox(height: 12),
          const ClinicalDisclaimerBanner(),
        ],
      ],
    );
  }

  void _jumpTo(_Step target) {
    final index = _steps.indexOf(target);
    if (index >= 0) setState(() => stepIndex = index);
  }

  Widget _summaryCard(Assessment assessment) {
    final readiness = assessment.protocolReadiness;
    String measured(int value, [String suffix = '%']) =>
        value > 0 ? '$value$suffix' : 'not measured';
    final rows = [
      MapEntry(
        'Surgery',
        '${formatDate(assessment.surgeryDate)} (week ${assessment.weeksPostOp})',
      ),
      MapEntry('Graft', assessment.graftType.label),
      MapEntry(
        'Pain / swelling',
        '${assessment.pain}/10, ${assessment.swelling.label.toLowerCase()}',
      ),
      MapEntry(
        'Range of motion',
        '${assessment.canStraighten ? 'Full' : 'Limited'} extension, '
            '${assessment.canBend ? 'functional' : 'limited'} flexion',
      ),
      MapEntry(
        'Walking',
        '${assessment.walkingQuality.label}, ${assessment.weightBearing.label.toLowerCase()} weight bearing',
      ),
      MapEntry('Confidence', '${assessment.confidence}/10'),
      MapEntry(
        'Strength symmetry',
        'Quad ${measured(readiness.quadStrengthSymmetry)}, '
            'hamstring ${measured(readiness.hamstringStrengthSymmetry)}, '
            'hip ${measured(readiness.gluteStrengthSymmetry)}',
      ),
      MapEntry(
        'Balance / hop',
        '${measured(readiness.balanceSymmetry)} / ${measured(readiness.hopTestSymmetry)}',
      ),
      MapEntry(
        'Restrictions',
        assessment.restrictions.isEmpty
            ? 'None listed'
            : assessment.restrictions.join(', '),
      ),
      MapEntry('Goal', assessment.profile.goalSummary),
      MapEntry(
        'Schedule',
        '${assessment.profile.sessionsPerWeek} days x ${assessment.profile.minutesPerSession} min',
      ),
      MapEntry(
        'Equipment',
        assessment.profile.equipment.isEmpty
            ? 'Household basics only'
            : assessment.profile.equipment.map((item) => item.label).join(', '),
      ),
    ];

    return Card(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            'Your answers',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 130, child: Text(row.key)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        row.value,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _stepTitle(_Step value) {
    switch (value) {
      case _Step.timeline:
        return 'Surgery Timeline';
      case _Step.graft:
        return 'Graft Type';
      case _Step.symptoms:
        return 'Current Symptoms';
      case _Step.readiness:
        return 'Protocol Readiness';
      case _Step.restrictions:
        return 'Restrictions';
      case _Step.setup:
        return 'Goals & Training Setup';
      case _Step.review:
        return widget.mode == AssessmentMode.reassessment
            ? 'Your Progress'
            : 'Your Plan';
    }
  }

  String _stepDescription(_Step value) {
    switch (value) {
      case _Step.timeline:
        return 'Set your surgery date to calculate weeks post-op.';
      case _Step.graft:
        return 'Graft-specific precautions shape how some exercises are loaded.';
      case _Step.symptoms:
        return widget.mode == AssessmentMode.reassessment
            ? 'Answers start from your last results. Update anything that changed.'
            : 'Pain, swelling, movement, and warning signs.';
      case _Step.readiness:
        return 'Criteria used in modern ACL rehab protocols. Use PT-measured values when available.';
      case _Step.restrictions:
        return 'Clinical restrictions that must block certain exercises.';
      case _Step.setup:
        return 'Your goal, time, and equipment decide which exercises fit you.';
      case _Step.review:
        return widget.mode == AssessmentMode.reassessment
            ? 'Compare with your last assessment and preview the updated plan.'
            : 'How your answers shape your plan. Every plan is checked before it is shown.';
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
    if (picked == null) return;
    HapticFeedback.selectionClick();
    setState(() {
      surgeryDate = picked;
      if (!_restrictionsTouched) {
        final weeks = (now.difference(picked).inDays / 7).floor();
        restrictions = weeks < 12 ? const ['No Running'] : const [];
      }
    });
  }

  Future<void> _handleNext() async {
    if (step == _Step.timeline && surgeryDate == null) {
      _showMessage('Please select your surgery date to continue.');
      return;
    }
    if (step == _Step.graft && graftType == null) {
      _showMessage('Please choose a graft type to continue.');
      return;
    }
    if (!_isLastStep) {
      HapticFeedback.selectionClick();
      setState(() => stepIndex++);
      return;
    }

    final assessment = draftAssessment;
    if (assessment == null) {
      _showMessage('Please complete the assessment before continuing.');
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);
    final controller = ref.read(appControllerProvider.notifier);
    try {
      switch (widget.mode) {
        case AssessmentMode.initial:
          await controller.completeOnboarding(assessment);
          if (mounted) context.go(AppRoutes.dashboard);
        case AssessmentMode.retake:
          await controller.completeOnboarding(
            assessment,
            kind: AssessmentKind.retake,
          );
          if (mounted) context.go(AppRoutes.dashboard);
        case AssessmentMode.reassessment:
          final recordId = await controller.completeReassessment(assessment);
          if (mounted) context.pushReplacement(AppRoutes.resultsFor(recordId));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        showSaveError(context);
      }
    }
  }

  Future<void> _confirmLeave() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave without saving?'),
        content: const Text('Your answers in this session will be discarded.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.dashboard);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _Collapsible extends StatelessWidget {
  const _Collapsible({
    required this.title,
    required this.subtitle,
    required this.initiallyExpanded,
    required this.children,
  });

  final String title;
  final String subtitle;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          title: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          subtitle: Text(subtitle),
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 10),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _PlanPreviewCard extends StatelessWidget {
  const _PlanPreviewCard({required this.evaluation, required this.plan});

  final PhaseEvaluation evaluation;
  final RehabPlan plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final exercises = plan.allExercises
        .map((item) => ExerciseCatalog.byId(item.exerciseId)?.name)
        .whereType<String>()
        .toList();
    final report = plan.validation;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Suggested phase',
              style: textTheme.titleSmall?.copyWith(
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              evaluation.phase.label,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            RehabPhaseTimeline(
              phase: evaluation.phase,
              progress: evaluation.progress,
            ),
            if (plan.focusAreas.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'What your plan focuses on',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final area in plan.focusAreas)
                    Chip(
                      avatar: Icon(
                        area.priority == FocusPriority.high
                            ? Icons.priority_high
                            : Icons.adjust,
                        size: 16,
                      ),
                      label: Text(area.title),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Text(
              '${exercises.length} exercises · ${plan.sessions.length} '
              '${plan.sessions.length == 1 ? 'session' : 'sessions'} · '
              '${plan.sessionsPerWeek} days a week · about ${plan.minutesPerSession} min',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              exercises.isEmpty
                  ? 'No exercises unlocked yet. Review the criteria below with your team.'
                  : exercises.join(' · '),
              style: TextStyle(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.verified_outlined,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Quality check: ${report.passed} passed'
                    '${report.adjusted > 0 ? ', ${report.adjusted} adjusted' : ''}'
                    '${report.warnings > 0 ? ', ${report.warnings} to review' : ''}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (evaluation.blockers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Next milestones',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              for (final blocker in evaluation.blockers.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    blocker,
                    style: TextStyle(color: scheme.onPrimaryContainer),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChangesCard extends StatelessWidget {
  const _ChangesCard({required this.comparison});

  final AssessmentComparison comparison;

  @override
  Widget build(BuildContext context) {
    final improvements = comparison.improvements;
    final declines = comparison.declines;
    final textTheme = Theme.of(context).textTheme;
    final phaseText = comparison.phaseDelta > 0
        ? 'Moves you up to ${comparison.currentPhase.label}.'
        : comparison.phaseDelta < 0
        ? 'Moves you back to ${comparison.currentPhase.label}.'
        : 'Keeps you in ${comparison.currentPhase.label}.';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Changes since your last assessment',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(phaseText),
            const SizedBox(height: 10),
            if (improvements.isEmpty && declines.isEmpty)
              const Text(
                'No changes yet. Update the answers that are different now.',
              ),
            for (final item in improvements.take(5))
              _ChangeRow(item: item, improved: true),
            for (final item in declines.take(3))
              _ChangeRow(item: item, improved: false),
          ],
        ),
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({required this.item, required this.improved});

  final MetricChange item;
  final bool improved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            improved ? Icons.trending_up : Icons.trending_down,
            size: 18,
            color: improved ? AppTheme.teal : AppTheme.softRed,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(item.label)),
          Text(
            '${item.before} -> ${item.after}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
