import 'dart:math' as math;

import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/assessment_consistency.dart';
import 'package:acl_rehab/domain/services/focus_analyzer.dart';
import 'package:acl_rehab/domain/services/plan_validator.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';

class PlanGenerationInput {
  const PlanGenerationInput({
    required this.assessment,
    this.milestone,
    this.progressions = const {},
    this.previousPlan,
    this.trigger = PlanTrigger.initial,
    this.assessmentRecordId,
    this.version = 1,
    this.now,
  });

  final Assessment assessment;
  final MilestoneCheckIn? milestone;
  final Map<String, ExerciseProgressionState> progressions;
  final RehabPlan? previousPlan;
  final PlanTrigger trigger;
  final String? assessmentRecordId;
  final int version;
  final DateTime? now;
}

/// The outcome of filling one plan slot.
class SlotSelection {
  const SlotSelection({
    required this.exercise,
    this.substitutedFrom,
    this.substitutionReason,
    this.note,
  });

  final Exercise exercise;
  final Exercise? substitutedFrom;
  final String? substitutionReason;

  /// Extra context for the exercise reason, such as a progression.
  final String? note;
}

/// Everything the generator and validator know about the user.
class PlanContext {
  PlanContext._({
    required this.assessment,
    required this.milestone,
    required this.status,
    required this.evaluation,
    required this.focusAreas,
    required this.progressions,
    required this.previousPlan,
    required this.trigger,
    required this.consistency,
  });

  factory PlanContext.from(PlanGenerationInput input) {
    final status = RehabStatus.from(
      input.assessment,
      milestone: input.milestone,
    );
    final evaluation = evaluateRehabPhase(
      input.assessment,
      milestone: input.milestone,
    );
    return PlanContext._(
      assessment: input.assessment,
      milestone: input.milestone,
      status: status,
      evaluation: evaluation,
      focusAreas: FocusAnalyzer.analyze(
        status,
        evaluation.phase,
        input.assessment.profile,
      ),
      progressions: input.progressions,
      previousPlan: input.previousPlan,
      trigger: input.trigger,
      consistency: checkAssessmentConsistency(input.assessment),
    );
  }

  final Assessment assessment;
  final MilestoneCheckIn? milestone;
  final RehabStatus status;
  final PhaseEvaluation evaluation;
  final List<FocusArea> focusAreas;
  final Map<String, ExerciseProgressionState> progressions;
  final RehabPlan? previousPlan;
  final PlanTrigger trigger;
  final List<ConsistencyIssue> consistency;

  RehabPhase get phase => evaluation.phase;

  TrainingProfile get profile => assessment.profile;

  /// Minutes available for exercises after a five-minute warm-up.
  int get sessionBudget => math.max(10, profile.minutesPerSession - 5);

  /// Prefer the easiest variation when symptoms or confidence call for it.
  bool get gentle =>
      status.symptomsElevated || status.symptomsMild || status.confidence <= 4;

  bool isUnlocked(Exercise exercise) =>
      exercise.unlockStatus(assessment, milestone).isUnlocked;

  bool hasEquipment(Exercise exercise) => exercise.isAvailableWith(profile);

  bool allowedByGoal(TrainingPurpose purpose) {
    final goal = profile.goal;
    switch (purpose) {
      case TrainingPurpose.running:
        return goal.includesRunning;
      case TrainingPurpose.plyometric:
        return goal.includesPlyometrics;
      case TrainingPurpose.changeOfDirection:
        return goal.includesChangeOfDirection;
      case TrainingPurpose.landing:
        return goal.includesLanding;
      default:
        return true;
    }
  }

  int levelFor(String exerciseId) => progressions[exerciseId]?.level ?? 0;

  FocusArea? focusFor(TrainingPurpose purpose) {
    for (final area in focusAreas) {
      if (area.type.purposes.contains(purpose)) return area;
    }
    return null;
  }

  static int rank(Exercise exercise) =>
      exercise.difficultyLevel.index * 10 + exercise.phase.order;

  /// Picks the best exercise for [purpose], or null when nothing unlocked
  /// exists. The returned selection may be a same-goal substitute when the
  /// ideal exercise needs equipment the user does not have.
  SlotSelection? select(
    TrainingPurpose purpose, {
    Set<String> exclude = const {},
  }) {
    final unlocked = ExerciseCatalog.all
        .where(
          (exercise) =>
              exercise.purpose == purpose &&
              exercise.phase.order <= phase.order &&
              !exclude.contains(exercise.id) &&
              isUnlocked(exercise),
        )
        .toList();
    if (unlocked.isEmpty) return null;

    final ideal = _ideal(purpose, unlocked);
    if (hasEquipment(ideal.exercise)) return ideal;

    final available = unlocked.where(hasEquipment).toList();
    if (available.isEmpty) return null;
    final idealRank = rank(ideal.exercise);
    // The ideal exercise's curated alternatives come first, then the
    // closest difficulty, then the most recent phase.
    final curated = ideal.exercise.alternativeExerciseIds;
    int curatedIndex(Exercise item) {
      final index = curated.indexOf(item.id);
      return index < 0 ? curated.length : index;
    }

    available.sort((a, b) {
      final byCurated = curatedIndex(a).compareTo(curatedIndex(b));
      if (byCurated != 0) return byCurated;
      final byDistance = (rank(a) - idealRank).abs().compareTo(
        (rank(b) - idealRank).abs(),
      );
      if (byDistance != 0) return byDistance;
      return b.phase.order.compareTo(a.phase.order);
    });
    final pick = available.first;
    final missing = ideal.exercise
        .missingEquipment(profile)
        .map((item) => item.label.toLowerCase())
        .join(' or ');
    return SlotSelection(
      exercise: pick,
      substitutedFrom: ideal.exercise,
      substitutionReason:
          'No $missing: ${pick.name} trains the same goal '
          '(${purpose.label.toLowerCase()}) instead of ${ideal.exercise.name}.',
    );
  }

  /// The best exercise ignoring equipment, keeping continuity with the
  /// previous plan and moving harder or easier based on feedback.
  SlotSelection _ideal(TrainingPurpose purpose, List<Exercise> unlocked) {
    final topPhase = unlocked.map((item) => item.phase.order).reduce(math.max);
    final tier = unlocked
        .where((item) => item.phase.order == topPhase)
        .toList();

    final previous = _previousFor(purpose, unlocked);
    if (previous != null && previous.phase.order == topPhase) {
      final level = levelFor(previous.id);
      if (level >= ExerciseProgressionState.maxLevel) {
        final harder = _step(previous, unlocked, harder: true);
        if (harder != null) {
          return SlotSelection(
            exercise: harder,
            note:
                'Progressed from ${previous.name} after it reached its top level.',
          );
        }
      }
      if (level <= ExerciseProgressionState.minLevel) {
        final easier = _step(previous, unlocked, harder: false);
        if (easier != null) {
          return SlotSelection(
            exercise: easier,
            note:
                'Swapped in for ${previous.name} after repeated "too hard" feedback.',
          );
        }
      }
      return SlotSelection(exercise: previous);
    }

    if (_criterionMet(purpose)) {
      // Within equal difficulty, later catalog entries are later progressions.
      final hardest = tier.reduce((a, b) => rank(b) >= rank(a) ? b : a);
      return SlotSelection(
        exercise: hardest,
        note: hardest.id == tier.first.id
            ? null
            : 'Harder variation chosen because you already meet the '
                  '${purpose.label.toLowerCase()} criteria for this stage.',
      );
    }
    if (gentle) {
      final easiest = tier.reduce(
        (a, b) => a.difficultyLevel.index <= b.difficultyLevel.index ? a : b,
      );
      return SlotSelection(
        exercise: easiest,
        note: easiest.id == tier.first.id
            ? null
            : 'Easier variation chosen while ${_gentleReason()}.',
      );
    }
    return SlotSelection(exercise: tier.first);
  }

  /// Whether the user already meets the readiness criterion that the
  /// entry-level exercise for [purpose] builds toward.
  bool _criterionMet(TrainingPurpose purpose) {
    if (gentle) return false;
    switch (purpose) {
      case TrainingPurpose.running:
        return status.completedJogRunProgram;
      case TrainingPurpose.landing:
        return status.goodLandingControl;
      default:
        return false;
    }
  }

  Exercise? _previousFor(TrainingPurpose purpose, List<Exercise> unlocked) {
    final plan = previousPlan;
    if (plan == null || trigger == PlanTrigger.profileChange) return null;
    for (final item in plan.allExercises) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise != null &&
          exercise.purpose == purpose &&
          unlocked.contains(exercise) &&
          hasEquipment(exercise)) {
        return exercise;
      }
    }
    return null;
  }

  Exercise? _step(
    Exercise from,
    List<Exercise> unlocked, {
    required bool harder,
  }) {
    final base = rank(from);
    final candidates = unlocked
        .where(
          (item) =>
              item.id != from.id &&
              hasEquipment(item) &&
              (harder ? rank(item) > base : rank(item) < base),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) =>
          harder ? rank(a).compareTo(rank(b)) : rank(b).compareTo(rank(a)),
    );
    return candidates.first;
  }

  String _gentleReason() {
    if (status.symptomsElevated || status.symptomsMild) {
      return 'pain is ${status.pain}/10 with '
          '${status.swelling.label.toLowerCase()} swelling';
    }
    return 'confidence is ${status.confidence}/10';
  }

  /// A plan entry for [selection], dosed for this user.
  PlanExercise toPlanExercise(
    SlotSelection selection, {
    required int priority,
    FocusArea? focus,
    bool boostVolume = true,
  }) {
    final exercise = selection.exercise;
    final reasonParts = <String>[
      focus != null
          ? 'Addresses: ${focus.title.toLowerCase()}.'
          : 'Core ${exercise.purpose.label.toLowerCase()} work for ${phase.label}.',
      ?selection.note,
    ];
    return PlanExercise(
      exerciseId: exercise.id,
      prescription: prescribe(exercise, focus: focus, boostVolume: boostVolume),
      reason: reasonParts.join(' '),
      priority: priority,
      focus: focus?.type,
      substitutedFromId: selection.substitutedFrom?.id,
      substitutionReason: selection.substitutionReason,
    );
  }

  Prescription prescribe(
    Exercise exercise, {
    FocusArea? focus,
    bool boostVolume = true,
  }) {
    final purpose = exercise.purpose;
    final continuous = exercise.sets <= 1;
    final level = levelFor(exercise.id);
    var sets = exercise.sets;
    if (!continuous) {
      if (status.symptomsElevated && !purpose.isMotionOrActivation) sets -= 1;
      if (boostVolume &&
          focus?.priority == FocusPriority.high &&
          status.quietKnee) {
        sets += 1;
      }
      sets += level;
    }

    return Prescription(
      sets: continuous ? 1 : sets.clamp(1, 6),
      reps: exercise.reps,
      hold: exercise.holdTime,
      restSeconds: _restFor(exercise),
      effort: _effortFor(exercise),
      frequency: _frequencyFor(exercise, focus),
      level: level,
    );
  }

  int _restFor(Exercise exercise) {
    switch (exercise.purpose) {
      case TrainingPurpose.kneeExtension:
      case TrainingPurpose.kneeFlexion:
      case TrainingPurpose.circulation:
        return 15;
      case TrainingPurpose.conditioning:
        return 0;
      case TrainingPurpose.quadActivation:
      case TrainingPurpose.balance:
      case TrainingPurpose.coreStability:
        return 30;
      case TrainingPurpose.changeOfDirection:
        return 120;
      case TrainingPurpose.landing:
      case TrainingPurpose.plyometric:
      case TrainingPurpose.running:
        return 90;
      default:
        switch (exercise.difficultyLevel) {
          case DifficultyLevel.foundation:
            return 45;
          case DifficultyLevel.moderate:
            return 60;
          case DifficultyLevel.advanced:
          case DifficultyLevel.sport:
            return 90;
        }
    }
  }

  String _effortFor(Exercise exercise) {
    switch (exercise.purpose) {
      case TrainingPurpose.kneeExtension:
      case TrainingPurpose.kneeFlexion:
        return 'Gentle stretch, no sharp pain';
      case TrainingPurpose.circulation:
        return 'Easy, steady rhythm';
      case TrainingPurpose.quadActivation:
        return 'Firm contraction; quality over quantity';
      case TrainingPurpose.conditioning:
        return 'Easy: you can hold a conversation';
      case TrainingPurpose.balance:
        return 'Controlled: knee stays aligned over the foot';
      case TrainingPurpose.coreStability:
        return 'Controlled: steady breathing, no knee pain';
      default:
        break;
    }
    if (exercise.isHighImpact) {
      return 'Quality first: stop when landings get noisy or uneven';
    }
    if (status.symptomsElevated || status.symptomsMild) {
      return 'Easy: keep pain at 3/10 or lower';
    }
    switch (phase) {
      case RehabPhase.protectionAndMotion:
        return 'Light: pain 3/10 or lower';
      case RehabPhase.earlyStrengthening:
        return 'Moderate: RPE 5-6, 3-4 reps in reserve';
      case RehabPhase.advancedStrength:
      case RehabPhase.neuromuscularControl:
      case RehabPhase.returnToSport:
        return 'Challenging: RPE 7-8, 2-3 reps in reserve';
    }
  }

  String _frequencyFor(Exercise exercise, FocusArea? focus) {
    final early = phase == RehabPhase.protectionAndMotion;
    switch (exercise.purpose) {
      case TrainingPurpose.kneeExtension:
      case TrainingPurpose.kneeFlexion:
        if (early) return 'Daily, 2-3 times a day';
        return focus != null
            ? 'Daily until range is full'
            : 'Each training day';
      case TrainingPurpose.circulation:
        return 'Several times a day while swelling persists';
      case TrainingPurpose.quadActivation:
        return early ? 'Daily' : 'Each training day';
      case TrainingPurpose.conditioning:
        return 'Warm-up each training day';
      default:
        if (exercise.isHighImpact) {
          return 'Up to 2-3 times a week, never on back-to-back days';
        }
        return 'Each training day';
    }
  }

  /// Why a purpose could not be filled, based on its first locked exercise.
  PlanNote lockedNote(TrainingPurpose purpose) {
    final candidates =
        ExerciseCatalog.all
            .where(
              (exercise) =>
                  exercise.purpose == purpose &&
                  exercise.phase.order <= phase.order + 1,
            )
            .toList()
          ..sort((a, b) {
            final aDistance = (a.phase.order - phase.order).abs();
            final bDistance = (b.phase.order - phase.order).abs();
            return aDistance.compareTo(bDistance);
          });
    if (candidates.isEmpty) {
      return PlanNote(
        title: purpose.label,
        detail: 'Not part of ${phase.label} yet.',
      );
    }
    final target = candidates.first;
    final reasons = target.unlockStatus(assessment, milestone).reasons;
    return PlanNote(
      title: purpose.label,
      detail: reasons.isEmpty
          ? '${target.name} is not part of this phase yet.'
          : '${target.name} unlocks when: ${reasons.take(2).join(' ')}',
    );
  }
}

class _Slot {
  const _Slot(
    this.purpose,
    this.priority, {
    this.optional = false,
    this.secondary = false,
  });

  final TrainingPurpose purpose;
  final int priority;

  /// Optional slots are skipped silently when they cannot be filled.
  final bool optional;

  /// A second exercise for a high-priority weakness, dosed at base volume.
  final bool secondary;
}

/// Generates a personalized, validated rehabilitation plan.
class PlanGenerator {
  const PlanGenerator._();

  /// Base priority of each purpose by phase. Higher numbers come first and
  /// survive when a session has to be shortened.
  static const Map<RehabPhase, Map<TrainingPurpose, int>> _blueprints = {
    RehabPhase.protectionAndMotion: {
      TrainingPurpose.kneeExtension: 10,
      TrainingPurpose.quadActivation: 9,
      TrainingPurpose.kneeFlexion: 8,
      TrainingPurpose.hipStability: 5,
      TrainingPurpose.balance: 4,
      TrainingPurpose.calfStrength: 4,
    },
    RehabPhase.earlyStrengthening: {
      TrainingPurpose.quadStrength: 9,
      TrainingPurpose.singleLegStrength: 8,
      TrainingPurpose.posteriorChain: 7,
      TrainingPurpose.hipStability: 6,
      TrainingPurpose.balance: 6,
      TrainingPurpose.calfStrength: 4,
      TrainingPurpose.hamstringStrength: 4,
      TrainingPurpose.conditioning: 3,
      TrainingPurpose.coreStability: 3,
    },
    RehabPhase.advancedStrength: {
      TrainingPurpose.quadStrength: 9,
      TrainingPurpose.singleLegStrength: 9,
      TrainingPurpose.posteriorChain: 7,
      TrainingPurpose.hamstringStrength: 7,
      TrainingPurpose.balance: 6,
      TrainingPurpose.hipStability: 5,
      TrainingPurpose.calfStrength: 4,
      TrainingPurpose.coreStability: 4,
    },
    RehabPhase.neuromuscularControl: {
      TrainingPurpose.singleLegStrength: 9,
      TrainingPurpose.landing: 8,
      TrainingPurpose.running: 7,
      TrainingPurpose.balance: 7,
      TrainingPurpose.posteriorChain: 6,
      TrainingPurpose.quadStrength: 6,
      TrainingPurpose.plyometric: 5,
      TrainingPurpose.hamstringStrength: 4,
      TrainingPurpose.calfStrength: 3,
      TrainingPurpose.coreStability: 4,
    },
    RehabPhase.returnToSport: {
      TrainingPurpose.changeOfDirection: 9,
      TrainingPurpose.plyometric: 8,
      TrainingPurpose.running: 7,
      TrainingPurpose.singleLegStrength: 7,
      TrainingPurpose.posteriorChain: 6,
      TrainingPurpose.quadStrength: 6,
      TrainingPurpose.landing: 5,
      TrainingPurpose.balance: 5,
      TrainingPurpose.hamstringStrength: 4,
      TrainingPurpose.coreStability: 3,
    },
  };

  /// Purposes that only make sense when their equipment is available.
  static const _optionalPurposes = {TrainingPurpose.conditioning};

  static const _sessionOrder = [
    TrainingPurpose.conditioning,
    TrainingPurpose.kneeExtension,
    TrainingPurpose.kneeFlexion,
    TrainingPurpose.quadActivation,
    TrainingPurpose.changeOfDirection,
    TrainingPurpose.running,
    TrainingPurpose.plyometric,
    TrainingPurpose.landing,
    TrainingPurpose.quadStrength,
    TrainingPurpose.singleLegStrength,
    TrainingPurpose.posteriorChain,
    TrainingPurpose.hamstringStrength,
    TrainingPurpose.hipStability,
    TrainingPurpose.coreStability,
    TrainingPurpose.balance,
    TrainingPurpose.calfStrength,
    TrainingPurpose.circulation,
  ];

  /// Priority at or above this value marks an exercise that belongs in every
  /// session, such as extension work while extension is limited.
  static const criticalPriority = 14;

  static RehabPlan generate(PlanGenerationInput input) {
    final context = PlanContext.from(input);
    final now = input.now ?? DateTime.now();
    final slots = _slotsFor(context);

    final chosen = <PlanExercise>[];
    final excluded = <PlanNote>[];
    final usedIds = <String>{};
    final notedPurposes = <TrainingPurpose>{};

    for (final slot in slots) {
      final selection = context.select(slot.purpose, exclude: usedIds);
      if (selection == null) {
        if (!slot.optional && notedPurposes.add(slot.purpose)) {
          excluded.add(_unfilledNote(context, slot.purpose));
        }
        continue;
      }
      usedIds.add(selection.exercise.id);
      chosen.add(
        context.toPlanExercise(
          selection,
          priority: slot.priority,
          focus: context.focusFor(slot.purpose),
          boostVolume: !slot.secondary,
        ),
      );
    }
    excluded.addAll(_goalExclusions(context));

    final sessions = buildSessions(chosen, context);
    final draft = RehabPlan(
      id: 'plan-${now.microsecondsSinceEpoch}',
      version: input.version,
      createdAt: now,
      trigger: input.trigger,
      assessmentRecordId: input.assessmentRecordId,
      phase: context.phase,
      weekPostOp: context.status.weeksPostOp,
      goal: context.profile.goal,
      sessionsPerWeek: context.profile.sessionsPerWeek,
      minutesPerSession: context.profile.minutesPerSession,
      focusAreas: context.focusAreas,
      rationale: const [],
      sessions: sessions,
      weeklySchedule: buildSchedule(
        sessionsPerWeek: context.profile.sessionsPerWeek,
        sessions: sessions,
        phase: context.phase,
      ),
      excluded: excluded,
      progressionRules: _progressionRules(context.phase),
      reassessAfterDays: _reassessAfterDays(context),
      validation: const PlanValidationReport(checks: []),
    );

    final validated = PlanValidator.validateAndRepair(draft, context);
    return validated.copyWith(rationale: _rationale(context, validated));
  }

  static List<_Slot> _slotsFor(PlanContext context) {
    final priorities = Map<TrainingPurpose, int>.from(
      _blueprints[context.phase]!,
    );
    final goal = context.profile.goal;

    void bump(TrainingPurpose purpose, int amount) {
      final current = priorities[purpose];
      if (current != null) priorities[purpose] = current + amount;
    }

    switch (goal) {
      case RecoveryGoal.dailyActivities:
        bump(TrainingPurpose.balance, 2);
        bump(TrainingPurpose.singleLegStrength, 1);
        bump(TrainingPurpose.calfStrength, 1);
      case RecoveryGoal.fitness:
        bump(TrainingPurpose.conditioning, 2);
        if (priorities.containsKey(TrainingPurpose.running)) {
          priorities[TrainingPurpose.running] = 4;
        }
      case RecoveryGoal.running:
        bump(TrainingPurpose.running, 2);
        bump(TrainingPurpose.calfStrength, 2);
      case RecoveryGoal.returnToSport:
        bump(TrainingPurpose.landing, 1);
    }
    if (context.phase == RehabPhase.protectionAndMotion &&
        context.status.swelling != Swelling.none) {
      priorities[TrainingPurpose.circulation] = 6;
    }

    for (final area in context.focusAreas) {
      final boost = switch (area.priority) {
        FocusPriority.high => 4,
        FocusPriority.medium => 2,
        FocusPriority.low => 0,
      };
      final fallback = switch (area.priority) {
        FocusPriority.high => 8,
        FocusPriority.medium => 5,
        FocusPriority.low => 3,
      };
      for (final purpose in area.type.purposes) {
        priorities[purpose] = (priorities[purpose] ?? fallback) + boost;
      }
    }
    if (context.focusAreas.any(
      (area) =>
          area.type == FocusAreaType.extension &&
          area.priority == FocusPriority.high,
    )) {
      priorities[TrainingPurpose.kneeExtension] = 14;
    }
    priorities.removeWhere((purpose, _) => !context.allowedByGoal(purpose));

    final slots = [
      for (final entry in priorities.entries)
        _Slot(
          entry.key,
          entry.value,
          optional: _optionalPurposes.contains(entry.key),
        ),
    ];
    // A high-priority strength gap earns a second exercise for that purpose.
    for (final area in context.focusAreas) {
      if (area.priority != FocusPriority.high) continue;
      if (area.type == FocusAreaType.quadStrength) {
        slots.add(
          const _Slot(
            TrainingPurpose.quadStrength,
            7,
            optional: true,
            secondary: true,
          ),
        );
      }
      if (area.type == FocusAreaType.balance) {
        slots.add(
          const _Slot(
            TrainingPurpose.balance,
            5,
            optional: true,
            secondary: true,
          ),
        );
      }
    }
    slots.sort((a, b) => b.priority.compareTo(a.priority));
    return slots;
  }

  static PlanNote _unfilledNote(PlanContext context, TrainingPurpose purpose) {
    final anyUnlocked = ExerciseCatalog.all.any(
      (exercise) =>
          exercise.purpose == purpose &&
          exercise.phase.order <= context.phase.order &&
          context.isUnlocked(exercise),
    );
    // Nothing is unlocked yet, so criteria (not equipment) are the blocker.
    if (!anyUnlocked) return context.lockedNote(purpose);

    final needed = ExerciseCatalog.all
        .where(
          (exercise) =>
              exercise.purpose == purpose &&
              exercise.phase.order <= context.phase.order &&
              context.isUnlocked(exercise),
        )
        .expand((exercise) => exercise.missingEquipment(context.profile))
        .map((item) => item.label.toLowerCase())
        .toSet();
    return PlanNote(
      title: purpose.label,
      detail:
          'Every option needs equipment you have not listed (${needed.join(', ')}). '
          'Add it in Training setup to include this.',
    );
  }

  static List<PlanNote> _goalExclusions(PlanContext context) {
    if (context.phase.order < RehabPhase.neuromuscularControl.order) {
      return const [];
    }
    final skipped = <String>[
      if (!context.allowedByGoal(TrainingPurpose.changeOfDirection))
        'cutting and agility drills',
      if (!context.allowedByGoal(TrainingPurpose.plyometric)) 'hopping drills',
      if (!context.allowedByGoal(TrainingPurpose.running)) 'running drills',
      if (!context.allowedByGoal(TrainingPurpose.landing)) 'landing drills',
    ];
    if (skipped.isEmpty) return const [];
    return [
      PlanNote(
        title: 'Left out for your goal',
        detail:
            '${_capitalize(skipped.join(', '))} are not included because your '
            'goal is ${context.profile.goal.label.toLowerCase()}. Change your '
            'goal in Training setup if that changes.',
      ),
    ];
  }

  /// Splits exercises into one or two session templates.
  static List<PlanSession> buildSessions(
    List<PlanExercise> exercises,
    PlanContext context,
  ) {
    if (exercises.isEmpty) return const [];
    final total = exercises.fold<int>(
      0,
      (sum, item) => sum + estimateMinutesFor(item),
    );
    final singleSession =
        context.phase == RehabPhase.protectionAndMotion ||
        total <= context.sessionBudget;

    if (singleSession) {
      return [
        _session(
          'A',
          context.phase == RehabPhase.protectionAndMotion
              ? 'Motion & Activation'
              : 'Session A',
          exercises,
        ),
      ];
    }

    final shared = exercises
        .where(
          (item) =>
              item.priority >= criticalPriority ||
              ExerciseCatalog.byId(item.exerciseId)?.purpose ==
                  TrainingPurpose.circulation,
        )
        .toList();
    final rest = exercises.where((item) => !shared.contains(item)).toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final a = [...shared];
    final b = [...shared];
    int minutes(List<PlanExercise> items) =>
        items.fold(0, (sum, item) => sum + estimateMinutesFor(item));
    for (final item in rest) {
      (minutes(a) <= minutes(b) ? a : b).add(item);
    }
    return [_session('A', 'Session A', a), _session('B', 'Session B', b)];
  }

  static PlanSession _session(
    String id,
    String name,
    List<PlanExercise> exercises,
  ) {
    final ordered = orderForSession(exercises);
    return PlanSession(
      id: id,
      name: name,
      focus: sessionFocus(ordered),
      exercises: ordered,
      estimatedMinutes: sessionMinutes(ordered),
    );
  }

  /// Warm-up and motion first, impact work while fresh, then strength,
  /// balance, and circulation work to finish.
  static List<PlanExercise> orderForSession(List<PlanExercise> exercises) {
    int position(PlanExercise item) {
      final purpose = ExerciseCatalog.byId(item.exerciseId)?.purpose;
      return purpose == null ? 99 : _sessionOrder.indexOf(purpose);
    }

    return [...exercises]..sort((a, b) => position(a).compareTo(position(b)));
  }

  static String sessionFocus(List<PlanExercise> exercises) {
    final top = [...exercises]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final labels = <String>[];
    for (final item in top) {
      final label = ExerciseCatalog.byId(item.exerciseId)?.purpose.label;
      if (label != null && !labels.contains(label)) labels.add(label);
      if (labels.length == 2) break;
    }
    return labels.join(' · ');
  }

  /// Warm-up plus the estimated time of each exercise.
  static int sessionMinutes(List<PlanExercise> exercises) =>
      5 + exercises.fold(0, (sum, item) => sum + estimateMinutesFor(item));

  static int estimateMinutesFor(PlanExercise item) {
    final exercise = ExerciseCatalog.byId(item.exerciseId);
    if (exercise == null) return 0;
    return estimateMinutes(exercise, item.prescription);
  }

  static int estimateMinutes(Exercise exercise, Prescription prescription) {
    final holdMinutes = _minutesIn(prescription.hold);
    if (holdMinutes != null) {
      final total = prescription.sets <= 1
          ? holdMinutes
          : prescription.sets * holdMinutes;
      return math.max(1, total.round());
    }
    final perSide =
        prescription.reps.contains('each') ||
            exercise.name.toLowerCase().contains('single-leg')
        ? 2
        : 1;
    final seconds =
        prescription.sets * (40 * perSide + prescription.restSeconds) + 30;
    return math.max(1, (seconds / 60).round());
  }

  static double? _minutesIn(String text) {
    final match = RegExp(r'(\d+)(?:-(\d+))?\s*min').firstMatch(text);
    if (match == null) return null;
    final low = double.parse(match.group(1)!);
    final high = double.tryParse(match.group(2) ?? '') ?? low;
    return (low + high) / 2;
  }

  static const lightDayLabel = 'Light day: bike or walk + mobility';

  /// Seven day labels spreading sessions evenly across the week.
  static List<String> buildSchedule({
    required int sessionsPerWeek,
    required List<PlanSession> sessions,
    required RehabPhase phase,
    int lightDays = 0,
  }) {
    const layouts = {
      1: [0],
      2: [0, 3],
      3: [0, 2, 4],
      4: [0, 1, 3, 4],
      5: [0, 1, 2, 4, 5],
      6: [0, 1, 2, 3, 4, 5],
    };
    final count = sessionsPerWeek.clamp(1, 6);
    final days = layouts[count]!;
    final restLabel = phase == RehabPhase.protectionAndMotion
        ? 'Motion only'
        : 'Rest or easy walk';
    final schedule = List<String>.filled(7, restLabel);
    if (sessions.isEmpty) return schedule;
    for (var i = 0; i < days.length; i++) {
      schedule[days[i]] = sessions[i % sessions.length].name;
    }
    var remaining = lightDays;
    for (var day = 0; day < 7 && remaining > 0; day++) {
      if (schedule[day] == restLabel) {
        schedule[day] = lightDayLabel;
        remaining--;
      }
    }
    return schedule;
  }

  static List<String> _progressionRules(RehabPhase phase) {
    return [
      'Progress an exercise after 2 sessions rated "Just right" (or 1 rated '
          '"Too easy") with pain 2/10 or lower afterward.',
      'Keep the same dose when pain after exercise is 3-4/10.',
      'Step back a level when an exercise feels too hard, pain reaches 5/10, '
          'or swelling is worse the next morning.',
      'Each level adds or removes one set. At the top level, the next plan '
          'update moves you to a harder variation.',
      if (phase.order >= RehabPhase.neuromuscularControl.order)
        'Impact and running work only progresses when there is no swelling the next day.',
    ];
  }

  static int _reassessAfterDays(PlanContext context) {
    if (context.status.symptomsElevated || context.status.mechanicalSymptoms) {
      return 10;
    }
    switch (context.phase) {
      case RehabPhase.protectionAndMotion:
        return 14;
      case RehabPhase.earlyStrengthening:
        return 21;
      case RehabPhase.advancedStrength:
      case RehabPhase.neuromuscularControl:
      case RehabPhase.returnToSport:
        return 28;
    }
  }

  static List<PlanNote> _rationale(PlanContext context, RehabPlan plan) {
    final status = context.status;
    final notes = <PlanNote>[];
    final exercisesByFocus = <FocusAreaType, List<String>>{};
    for (final item in plan.allExercises) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise == null) continue;
      for (final area in context.focusAreas) {
        if (area.type.purposes.contains(exercise.purpose)) {
          exercisesByFocus.putIfAbsent(area.type, () => []).add(exercise.name);
        }
      }
    }

    final blockers = context.evaluation.blockers;
    notes.add(
      PlanNote(
        title: 'Why ${context.phase.shortLabel}: ${context.phase.label}',
        detail:
            'Week ${status.weeksPostOp} after surgery, pain ${status.pain}/10, '
            '${_swellingText(status.swelling)}, '
            '${status.fullExtension ? 'full' : 'limited'} extension and '
            '${status.walking.label.toLowerCase()} walking. '
            '${blockers.isEmpty ? 'Criteria for this phase are met.' : 'Next step: ${blockers.first}'}',
      ),
    );

    for (final area in context.focusAreas.take(5)) {
      if (area.priority == FocusPriority.low) continue;
      final names = exercisesByFocus[area.type] ?? const [];
      final addressed = switch (area.type) {
        FocusAreaType.pain || FocusAreaType.swelling when names.isEmpty =>
          'Volume and effort are reduced to match.',
        FocusAreaType.mechanicalSymptoms =>
          'Please contact your clinical team before progressing.',
        _ =>
          names.isEmpty
              ? 'Not addressable yet. See "Not in your plan yet".'
              : 'Addressed by ${names.toSet().join(', ')}.',
      };
      notes.add(
        PlanNote(title: area.title, detail: '${area.detail} $addressed'),
      );
    }

    notes.add(
      PlanNote(
        title: 'Goal: ${context.profile.goalSummary}',
        detail: _goalDetail(context),
      ),
    );

    final substitutions = plan.allExercises
        .where((item) => item.substitutedFromId != null)
        .length;
    if (substitutions > 0) {
      notes.add(
        PlanNote(
          title: 'Matched to your equipment',
          detail:
              '$substitutions ${substitutions == 1 ? 'exercise was' : 'exercises were'} '
              'swapped for same-goal options that fit what you have.',
        ),
      );
    }

    notes.add(
      PlanNote(
        title:
            '${plan.sessionsPerWeek} sessions a week, about ${plan.minutesPerSession} minutes',
        detail: plan.sessions.length > 1
            ? 'Exercises alternate between Session A and Session B so each '
                  'session fits your time while the week covers everything.'
            : 'Each session covers the full program.',
      ),
    );

    if (context.gentle) {
      notes.add(
        PlanNote(
          title: 'Dosed for your symptoms',
          detail: status.symptomsElevated
              ? 'Pain ${status.pain}/10 with ${_swellingText(status.swelling)}: '
                    'strength work is one set lighter and effort stays easy.'
              : status.symptomsMild
              ? 'Pain ${status.pain}/10 with ${_swellingText(status.swelling)}: '
                    'easier variations and easy effort until the knee is quiet.'
              : 'Confidence ${status.confidence}/10: the most controlled '
                    'variations come first.',
        ),
      );
    }

    final graftNote = _graftNote(context);
    if (graftNote != null) notes.add(graftNote);
    return notes;
  }

  static String _goalDetail(PlanContext context) {
    final goal = context.profile.goal;
    if (context.phase == RehabPhase.protectionAndMotion) {
      return 'Early recovery is the same for every goal: motion, swelling '
          'control, and quadriceps activation. Your goal shapes the plan from '
          'the strengthening phases onward.';
    }
    final late = context.phase.order >= RehabPhase.neuromuscularControl.order;
    switch (goal) {
      case RecoveryGoal.dailyActivities:
        return late
            ? 'Strength, balance, and stair control are emphasized. Running, '
                  'hopping, and cutting drills are left out.'
            : 'Balance and single-leg strength get extra priority for walking and stairs.';
      case RecoveryGoal.fitness:
        return late
            ? 'Strength and landing control are emphasized, with optional easy '
                  'running. Hopping and cutting drills are left out.'
            : context.profile.has(EquipmentType.stationaryBike)
            ? 'A stationary-bike warm-up is added for conditioning.'
            : 'Add a stationary bike in Training setup to include a conditioning warm-up.';
      case RecoveryGoal.running:
        return late
            ? 'Running progression, calf capacity, and hopping get extra priority. '
                  'Cutting drills are left out.'
            : 'Calf strength gets extra priority to prepare for running later.';
      case RecoveryGoal.returnToSport:
        return late
            ? 'Landing, hopping, running, and change-of-direction drills are '
                  'included as their criteria are met.'
            : 'Strength and control come first; sport drills unlock by criteria later.';
    }
  }

  static PlanNote? _graftNote(PlanContext context) {
    final weeks = context.status.weeksPostOp;
    switch (context.status.graftType) {
      case GraftType.hamstring:
        if (weeks >= 12) return null;
        return const PlanNote(
          title: 'Hamstring graft precautions',
          detail:
              'Resisted hamstring loading waits until about week 12. Bridges '
              'and unresisted curls keep the posterior chain working meanwhile.',
        );
      case GraftType.patellarTendon:
        if (context.status.pain < 3) return null;
        return const PlanNote(
          title: 'Patellar tendon graft',
          detail:
              'Front-of-knee pain guides loading, so shallow-range and isometric '
              'options are favored while pain is present.',
        );
      case GraftType.quadriceps:
        return null;
      case GraftType.allograft:
        return const PlanNote(
          title: 'Allograft',
          detail:
              'Progression stays conservative, and clinical clearance matters before impact work.',
        );
    }
  }

  static String _swellingText(Swelling swelling) => swelling == Swelling.none
      ? 'no swelling'
      : '${swelling.label.toLowerCase()} swelling';

  static String _capitalize(String text) =>
      text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';
}
