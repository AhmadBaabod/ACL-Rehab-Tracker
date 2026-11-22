import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/session_log.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';

enum PlanTrigger { initial, reassessment, checkIn, profileChange, retake }

enum FocusPriority { high, medium, low }

enum FocusAreaType {
  mechanicalSymptoms,
  extension,
  flexion,
  swelling,
  pain,
  quadActivation,
  gait,
  quadStrength,
  hamstringStrength,
  hipStrength,
  balance,
  landing,
  runningReadiness,
  hopSymmetry,
  confidence,
}

enum CheckStatus { passed, adjusted, warning }

extension PlanTriggerX on PlanTrigger {
  String get label {
    switch (this) {
      case PlanTrigger.initial:
        return 'Initial assessment';
      case PlanTrigger.reassessment:
        return 'Reassessment';
      case PlanTrigger.checkIn:
        return 'Check-in update';
      case PlanTrigger.profileChange:
        return 'Training setup changed';
      case PlanTrigger.retake:
        return 'Assessment corrected';
    }
  }
}

extension FocusPriorityX on FocusPriority {
  String get label {
    switch (this) {
      case FocusPriority.high:
        return 'High priority';
      case FocusPriority.medium:
        return 'Priority';
      case FocusPriority.low:
        return 'Maintain';
    }
  }

  int get weight {
    switch (this) {
      case FocusPriority.high:
        return 3;
      case FocusPriority.medium:
        return 2;
      case FocusPriority.low:
        return 1;
    }
  }
}

extension FocusAreaTypeX on FocusAreaType {
  /// Exercise purposes that directly address this focus area.
  Set<TrainingPurpose> get purposes {
    switch (this) {
      case FocusAreaType.mechanicalSymptoms:
        return const {};
      case FocusAreaType.extension:
        return const {TrainingPurpose.kneeExtension};
      case FocusAreaType.flexion:
        return const {TrainingPurpose.kneeFlexion};
      case FocusAreaType.swelling:
        return const {TrainingPurpose.circulation};
      case FocusAreaType.pain:
        return const {};
      case FocusAreaType.quadActivation:
        return const {TrainingPurpose.quadActivation};
      case FocusAreaType.gait:
        return const {TrainingPurpose.calfStrength, TrainingPurpose.balance};
      case FocusAreaType.quadStrength:
        return const {
          TrainingPurpose.quadStrength,
          TrainingPurpose.singleLegStrength,
        };
      case FocusAreaType.hamstringStrength:
        return const {
          TrainingPurpose.hamstringStrength,
          TrainingPurpose.posteriorChain,
        };
      case FocusAreaType.hipStrength:
        return const {TrainingPurpose.hipStability};
      case FocusAreaType.balance:
        return const {TrainingPurpose.balance};
      case FocusAreaType.landing:
        return const {TrainingPurpose.landing};
      case FocusAreaType.runningReadiness:
        return const {TrainingPurpose.running};
      case FocusAreaType.hopSymmetry:
        return const {TrainingPurpose.plyometric};
      case FocusAreaType.confidence:
        return const {TrainingPurpose.balance, TrainingPurpose.landing};
    }
  }
}

class FocusArea {
  const FocusArea({
    required this.type,
    required this.priority,
    required this.title,
    required this.detail,
  });

  final FocusAreaType type;
  final FocusPriority priority;
  final String title;

  /// The assessment evidence behind this focus area.
  final String detail;

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'priority': priority.name,
    'title': title,
    'detail': detail,
  };

  factory FocusArea.fromJson(Map<String, dynamic> data) {
    return FocusArea(
      type: FocusAreaType.values.firstWhere(
        (item) => item.name == data['type'],
        orElse: () => FocusAreaType.quadStrength,
      ),
      priority: FocusPriority.values.firstWhere(
        (item) => item.name == data['priority'],
        orElse: () => FocusPriority.medium,
      ),
      title: data['title'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
    );
  }
}

class Prescription {
  const Prescription({
    required this.sets,
    required this.reps,
    required this.hold,
    required this.restSeconds,
    required this.effort,
    required this.frequency,
    this.level = 0,
    this.paused = false,
  });

  final int sets;
  final String reps;
  final String hold;
  final int restSeconds;

  /// How hard the exercise should feel.
  final String effort;

  /// How often to perform it, for example "Each training day".
  final String frequency;

  /// Feedback-driven progression level applied to this dose.
  final int level;

  /// True when progression was paused because symptoms were elevated; the
  /// dose may still step down from feedback but will not step up.
  final bool paused;

  Prescription copyWith({
    int? sets,
    String? reps,
    String? hold,
    int? restSeconds,
    String? effort,
    String? frequency,
    int? level,
    bool? paused,
  }) {
    return Prescription(
      sets: sets ?? this.sets,
      reps: reps ?? this.reps,
      hold: hold ?? this.hold,
      restSeconds: restSeconds ?? this.restSeconds,
      effort: effort ?? this.effort,
      frequency: frequency ?? this.frequency,
      level: level ?? this.level,
      paused: paused ?? this.paused,
    );
  }

  String get summary {
    final holdText = hold == 'None' || hold.isEmpty ? '' : ' - $hold';
    return '$sets x $reps$holdText';
  }

  Map<String, dynamic> toJson() => {
    'sets': sets,
    'reps': reps,
    'hold': hold,
    'restSeconds': restSeconds,
    'effort': effort,
    'frequency': frequency,
    'level': level,
    'paused': paused,
  };

  factory Prescription.fromJson(Map<String, dynamic> data) {
    return Prescription(
      sets: data['sets'] as int? ?? 2,
      reps: data['reps'] as String? ?? '10',
      hold: data['hold'] as String? ?? 'None',
      restSeconds: data['restSeconds'] as int? ?? 60,
      effort: data['effort'] as String? ?? '',
      frequency: data['frequency'] as String? ?? 'Each training day',
      level: data['level'] as int? ?? 0,
      paused: data['paused'] as bool? ?? false,
    );
  }
}

class PlanExercise {
  const PlanExercise({
    required this.exerciseId,
    required this.prescription,
    required this.reason,
    required this.priority,
    this.focus,
    this.substitutedFromId,
    this.substitutionReason,
  });

  final String exerciseId;
  final Prescription prescription;

  /// Why this exercise is in the plan, in plain language.
  final String reason;

  /// Higher numbers are kept first when a session must be shortened.
  final int priority;
  final FocusAreaType? focus;

  /// The exercise that would normally fill this slot, when a substitute was
  /// chosen for equipment, symptoms, or user preference.
  final String? substitutedFromId;
  final String? substitutionReason;

  /// Today's dose: the planned prescription adjusted by feedback logged since
  /// the plan was created (one set per level).
  Prescription doseFor(ExerciseProgressionState? progress) {
    final planned = prescription;
    final level = progress?.level ?? planned.level;
    var delta = level - planned.level;
    if (planned.paused && delta > 0) delta = 0;
    if (delta == 0 || planned.sets <= 1) {
      return planned.copyWith(level: level);
    }
    return planned.copyWith(
      sets: (planned.sets + delta).clamp(1, 6),
      level: level,
    );
  }

  PlanExercise copyWith({
    String? exerciseId,
    Prescription? prescription,
    String? reason,
    int? priority,
    FocusAreaType? focus,
    String? substitutedFromId,
    String? substitutionReason,
    bool clearSubstitution = false,
  }) {
    return PlanExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      prescription: prescription ?? this.prescription,
      reason: reason ?? this.reason,
      priority: priority ?? this.priority,
      focus: focus ?? this.focus,
      substitutedFromId: clearSubstitution
          ? null
          : substitutedFromId ?? this.substitutedFromId,
      substitutionReason: clearSubstitution
          ? null
          : substitutionReason ?? this.substitutionReason,
    );
  }

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'prescription': prescription.toJson(),
    'reason': reason,
    'priority': priority,
    'focus': focus?.name,
    'substitutedFromId': substitutedFromId,
    'substitutionReason': substitutionReason,
  };

  factory PlanExercise.fromJson(Map<String, dynamic> data) {
    FocusAreaType? focus;
    for (final item in FocusAreaType.values) {
      if (item.name == data['focus']) focus = item;
    }
    return PlanExercise(
      exerciseId: data['exerciseId'] as String? ?? '',
      prescription: Prescription.fromJson(
        Map<String, dynamic>.from(data['prescription'] as Map? ?? const {}),
      ),
      reason: data['reason'] as String? ?? '',
      priority: data['priority'] as int? ?? 1,
      focus: focus,
      substitutedFromId: data['substitutedFromId'] as String?,
      substitutionReason: data['substitutionReason'] as String?,
    );
  }
}

class PlanSession {
  const PlanSession({
    required this.id,
    required this.name,
    required this.focus,
    required this.exercises,
    required this.estimatedMinutes,
  });

  final String id;
  final String name;
  final String focus;
  final List<PlanExercise> exercises;
  final int estimatedMinutes;

  PlanSession copyWith({
    String? name,
    String? focus,
    List<PlanExercise>? exercises,
    int? estimatedMinutes,
  }) {
    return PlanSession(
      id: id,
      name: name ?? this.name,
      focus: focus ?? this.focus,
      exercises: exercises ?? this.exercises,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
    );
  }

  int get totalSets =>
      exercises.fold(0, (total, item) => total + item.prescription.sets);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'focus': focus,
    'exercises': exercises.map((item) => item.toJson()).toList(),
    'estimatedMinutes': estimatedMinutes,
  };

  factory PlanSession.fromJson(Map<String, dynamic> data) {
    return PlanSession(
      id: data['id'] as String? ?? 'A',
      name: data['name'] as String? ?? 'Session',
      focus: data['focus'] as String? ?? '',
      exercises: (data['exercises'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                PlanExercise.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      estimatedMinutes: data['estimatedMinutes'] as int? ?? 0,
    );
  }
}

/// A short "because ... so ..." statement shown with the plan.
class PlanNote {
  const PlanNote({required this.title, required this.detail});

  final String title;
  final String detail;

  Map<String, dynamic> toJson() => {'title': title, 'detail': detail};

  factory PlanNote.fromJson(Map<String, dynamic> data) {
    return PlanNote(
      title: data['title'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
    );
  }
}

class ValidationCheck {
  const ValidationCheck({
    required this.id,
    required this.title,
    required this.status,
    required this.detail,
  });

  final String id;
  final String title;
  final CheckStatus status;
  final String detail;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'status': status.name,
    'detail': detail,
  };

  factory ValidationCheck.fromJson(Map<String, dynamic> data) {
    return ValidationCheck(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      status: CheckStatus.values.firstWhere(
        (item) => item.name == data['status'],
        orElse: () => CheckStatus.passed,
      ),
      detail: data['detail'] as String? ?? '',
    );
  }
}

class PlanValidationReport {
  const PlanValidationReport({required this.checks});

  final List<ValidationCheck> checks;

  int count(CheckStatus status) =>
      checks.where((check) => check.status == status).length;

  int get passed => count(CheckStatus.passed);

  int get adjusted => count(CheckStatus.adjusted);

  int get warnings => count(CheckStatus.warning);

  Map<String, dynamic> toJson() => {
    'checks': checks.map((check) => check.toJson()).toList(),
  };

  factory PlanValidationReport.fromJson(Map<String, dynamic> data) {
    return PlanValidationReport(
      checks: (data['checks'] as List<dynamic>? ?? const [])
          .map(
            (item) => ValidationCheck.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(),
    );
  }
}

class RehabPlan {
  const RehabPlan({
    required this.id,
    required this.version,
    required this.createdAt,
    required this.trigger,
    required this.phase,
    required this.weekPostOp,
    required this.goal,
    required this.sessionsPerWeek,
    required this.minutesPerSession,
    required this.focusAreas,
    required this.rationale,
    required this.sessions,
    required this.weeklySchedule,
    required this.excluded,
    required this.progressionRules,
    required this.reassessAfterDays,
    required this.validation,
    this.assessmentRecordId,
  });

  final String id;
  final int version;
  final DateTime createdAt;
  final PlanTrigger trigger;
  final String? assessmentRecordId;
  final RehabPhase phase;
  final int weekPostOp;
  final RecoveryGoal goal;

  /// Strength sessions per week (after validation).
  final int sessionsPerWeek;
  final int minutesPerSession;
  final List<FocusArea> focusAreas;
  final List<PlanNote> rationale;
  final List<PlanSession> sessions;

  /// Seven labels, one per day, for example "Session A" or "Rest".
  final List<String> weeklySchedule;

  /// Exercises or components not yet included, with the reason.
  final List<PlanNote> excluded;
  final List<String> progressionRules;
  final int reassessAfterDays;
  final PlanValidationReport validation;

  DateTime get reassessDueAt =>
      createdAt.add(Duration(days: reassessAfterDays));

  List<PlanExercise> get allExercises {
    final seen = <String>{};
    return [
      for (final session in sessions)
        for (final exercise in session.exercises)
          if (seen.add(exercise.exerciseId)) exercise,
    ];
  }

  Set<String> get exerciseIds =>
      allExercises.map((item) => item.exerciseId).toSet();

  PlanSession? sessionById(String id) {
    for (final session in sessions) {
      if (session.id == id) return session;
    }
    return null;
  }

  RehabPlan copyWith({
    List<PlanSession>? sessions,
    List<PlanNote>? rationale,
    List<PlanNote>? excluded,
    List<String>? weeklySchedule,
    int? sessionsPerWeek,
    PlanValidationReport? validation,
  }) {
    return RehabPlan(
      id: id,
      version: version,
      createdAt: createdAt,
      trigger: trigger,
      assessmentRecordId: assessmentRecordId,
      phase: phase,
      weekPostOp: weekPostOp,
      goal: goal,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      minutesPerSession: minutesPerSession,
      focusAreas: focusAreas,
      rationale: rationale ?? this.rationale,
      sessions: sessions ?? this.sessions,
      weeklySchedule: weeklySchedule ?? this.weeklySchedule,
      excluded: excluded ?? this.excluded,
      progressionRules: progressionRules,
      reassessAfterDays: reassessAfterDays,
      validation: validation ?? this.validation,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'version': version,
    'createdAt': createdAt.toIso8601String(),
    'trigger': trigger.name,
    'assessmentRecordId': assessmentRecordId,
    'phase': phase.name,
    'weekPostOp': weekPostOp,
    'goal': goal.name,
    'sessionsPerWeek': sessionsPerWeek,
    'minutesPerSession': minutesPerSession,
    'focusAreas': focusAreas.map((item) => item.toJson()).toList(),
    'rationale': rationale.map((item) => item.toJson()).toList(),
    'sessions': sessions.map((item) => item.toJson()).toList(),
    'weeklySchedule': weeklySchedule,
    'excluded': excluded.map((item) => item.toJson()).toList(),
    'progressionRules': progressionRules,
    'reassessAfterDays': reassessAfterDays,
    'validation': validation.toJson(),
  };

  factory RehabPlan.fromJson(Map<String, dynamic> data) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) parse) {
      return (data[key] as List<dynamic>? ?? const [])
          .map((item) => parse(Map<String, dynamic>.from(item as Map)))
          .toList();
    }

    final createdAt =
        DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now();
    return RehabPlan(
      id: data['id'] as String? ?? 'plan-${createdAt.microsecondsSinceEpoch}',
      version: data['version'] as int? ?? 1,
      createdAt: createdAt,
      trigger: PlanTrigger.values.firstWhere(
        (item) => item.name == data['trigger'],
        orElse: () => PlanTrigger.initial,
      ),
      assessmentRecordId: data['assessmentRecordId'] as String?,
      phase: RehabPhase.values.firstWhere(
        (item) => item.name == data['phase'],
        orElse: () => RehabPhase.protectionAndMotion,
      ),
      weekPostOp: data['weekPostOp'] as int? ?? 0,
      goal: RecoveryGoal.values.firstWhere(
        (item) => item.name == data['goal'],
        orElse: () => RecoveryGoal.fitness,
      ),
      sessionsPerWeek: data['sessionsPerWeek'] as int? ?? 3,
      minutesPerSession: data['minutesPerSession'] as int? ?? 30,
      focusAreas: list('focusAreas', FocusArea.fromJson),
      rationale: list('rationale', PlanNote.fromJson),
      sessions: list('sessions', PlanSession.fromJson),
      weeklySchedule: List<String>.from(
        data['weeklySchedule'] as List<dynamic>? ?? const [],
      ),
      excluded: list('excluded', PlanNote.fromJson),
      progressionRules: List<String>.from(
        data['progressionRules'] as List<dynamic>? ?? const [],
      ),
      reassessAfterDays: data['reassessAfterDays'] as int? ?? 21,
      validation: PlanValidationReport.fromJson(
        Map<String, dynamic>.from(data['validation'] as Map? ?? const {}),
      ),
    );
  }
}
