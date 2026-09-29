import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';

class _MutableSession {
  _MutableSession(this.id, this.name, this.items);

  final String id;
  String name;
  final List<PlanExercise> items;

  int get minutes => PlanGenerator.sessionMinutes(items);
}

class _Draft {
  _Draft(RehabPlan plan)
    : sessions = [
        for (final session in plan.sessions)
          _MutableSession(session.id, session.name, [...session.exercises]),
      ],
      excluded = [...plan.excluded],
      sessionsPerWeek = plan.sessionsPerWeek;

  final List<_MutableSession> sessions;
  final List<PlanNote> excluded;
  int sessionsPerWeek;
  int lightDays = 0;

  Iterable<PlanExercise> get items => sessions.expand((s) => s.items);

  Set<String> get ids => items.map((item) => item.exerciseId).toSet();

  List<PlanExercise> get uniqueItems {
    final seen = <String>{};
    return [
      for (final item in items)
        if (seen.add(item.exerciseId)) item,
    ];
  }

  bool hasPurpose(Set<TrainingPurpose> purposes) => items.any(
    (item) => purposes.contains(ExerciseCatalog.byId(item.exerciseId)?.purpose),
  );

  void replace(String id, PlanExercise replacement) {
    for (final session in sessions) {
      for (var i = 0; i < session.items.length; i++) {
        if (session.items[i].exerciseId == id) session.items[i] = replacement;
      }
    }
  }

  void remove(String id) {
    for (final session in sessions) {
      session.items.removeWhere((item) => item.exerciseId == id);
    }
  }

  void add(PlanExercise item) {
    if (sessions.isEmpty) {
      sessions.add(_MutableSession('A', 'Session A', []));
    }
    final target = sessions.reduce((a, b) => a.minutes <= b.minutes ? a : b);
    target.items.add(item);
  }

  void note(String title, String detail) {
    if (excluded.any((item) => item.title == title && item.detail == detail)) {
      return;
    }
    excluded.add(PlanNote(title: title, detail: detail));
  }
}

class _Check {
  _Check(this.id, this.title);

  final String id;
  final String title;
  final List<String> changes = [];
  final List<String> warnings = [];
  String passDetail = '';

  ValidationCheck result() {
    if (warnings.isNotEmpty) {
      return ValidationCheck(
        id: id,
        title: title,
        status: CheckStatus.warning,
        detail: [...changes, ...warnings].join(' '),
      );
    }
    if (changes.isNotEmpty) {
      return ValidationCheck(
        id: id,
        title: title,
        status: CheckStatus.adjusted,
        detail: changes.join(' '),
      );
    }
    return ValidationCheck(
      id: id,
      title: title,
      status: CheckStatus.passed,
      detail: passDetail,
    );
  }
}

/// Checks a draft plan against the assessment and repairs problems before the
/// plan is shown: unsafe or locked exercises, equipment conflicts, goal
/// mismatches, difficulty, graft precautions, focus coverage, balance, time,
/// weekly load, and contradictory answers.
class PlanValidator {
  const PlanValidator._();

  static const _maxPasses = 3;

  static RehabPlan validateAndRepair(RehabPlan draft, PlanContext context) {
    var plan = draft;
    final merged = <String, ValidationCheck>{};
    final order = <String>[];

    for (var pass = 0; pass < _maxPasses; pass++) {
      final work = _Draft(plan);
      final checks = _runChecks(work, context);
      plan = _build(plan, work, context);

      for (final check in checks) {
        if (!merged.containsKey(check.id)) order.add(check.id);
        final previous = merged[check.id];
        if (previous == null ||
            check.status == CheckStatus.warning ||
            (check.status == CheckStatus.adjusted &&
                previous.status == CheckStatus.passed)) {
          merged[check.id] = check;
        }
      }
      if (checks.every((check) => check.status != CheckStatus.adjusted)) {
        break;
      }
    }

    return plan.copyWith(
      validation: PlanValidationReport(
        checks: [for (final id in order) merged[id]!],
      ),
    );
  }

  static RehabPlan _build(RehabPlan plan, _Draft work, PlanContext context) {
    final kept = work.sessions.where((session) => session.items.isNotEmpty);
    final sessions = <PlanSession>[];
    for (final session in kept) {
      final id = String.fromCharCode(65 + sessions.length);
      final ordered = PlanGenerator.orderForSession(session.items);
      sessions.add(
        PlanSession(
          id: id,
          name: 'Session $id',
          focus: PlanGenerator.sessionFocus(ordered),
          exercises: ordered,
          estimatedMinutes: PlanGenerator.sessionMinutes(ordered),
        ),
      );
    }
    final named =
        sessions.length == 1 && context.phase == RehabPhase.protectionAndMotion
        ? [sessions.first.copyWith(name: 'Motion & Activation')]
        : sessions;

    return plan.copyWith(
      sessions: named,
      excluded: work.excluded,
      sessionsPerWeek: work.sessionsPerWeek,
      weeklySchedule: PlanGenerator.buildSchedule(
        sessionsPerWeek: work.sessionsPerWeek,
        sessions: named,
        phase: context.phase,
        lightDays: work.lightDays,
      ),
    );
  }

  static List<ValidationCheck> _runChecks(_Draft work, PlanContext context) {
    return [
      _safety(work, context),
      _graft(work, context),
      _equipment(work, context),
      _goal(work, context),
      _difficulty(work, context),
      _duplicates(work),
      _coverage(work, context),
      _balance(work, context),
      _symptomProgression(work, context),
      _timeBudget(work, context),
      _weeklyLoad(work, context),
      _consistency(context),
      _clinicalFlags(context),
      _notEmpty(work, context),
    ].map((check) => check.result()).toList();
  }

  static String _name(String id) => ExerciseCatalog.byId(id)?.name ?? id;

  /// Replaces [item] with a safe same-purpose option, or removes it.
  static String? _replaceOrRemove(
    _Draft work,
    PlanContext context,
    PlanExercise item,
    bool Function(Exercise candidate) accept,
  ) {
    final exercise = ExerciseCatalog.byId(item.exerciseId);
    if (exercise != null) {
      final exclude = {...work.ids};
      for (var attempt = 0; attempt < 6; attempt++) {
        final selection = context.select(exercise.purpose, exclude: exclude);
        if (selection == null) break;
        if (accept(selection.exercise)) {
          work.replace(
            item.exerciseId,
            context.toPlanExercise(
              selection,
              priority: item.priority,
              focus: context.focusFor(exercise.purpose),
            ),
          );
          return selection.exercise.name;
        }
        exclude.add(selection.exercise.id);
      }
    }
    work.remove(item.exerciseId);
    return null;
  }

  static _Check _safety(_Draft work, PlanContext context) {
    final check = _Check('safety', 'Safe for your current criteria');
    for (final item in work.uniqueItems) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise == null) {
        work.remove(item.exerciseId);
        check.changes.add('Removed an exercise that is no longer available.');
        continue;
      }
      final reasons = exercise
          .unlockStatus(context.assessment, context.milestone)
          .reasons;
      if (reasons.isEmpty) continue;
      final replacement = _replaceOrRemove(
        work,
        context,
        item,
        context.isUnlocked,
      );
      check.changes.add(
        replacement == null
            ? 'Removed ${exercise.name}: ${reasons.first}'
            : 'Replaced ${exercise.name} with $replacement: ${reasons.first}',
      );
    }
    check.passDetail =
        'All ${work.ids.length} exercises meet their unlock criteria and your '
        'listed restrictions.';
    return check;
  }

  static _Check _graft(_Draft work, PlanContext context) {
    final check = _Check('graft', 'Graft precautions respected');
    final graft = context.status.graftType;
    final weeks = context.status.weeksPostOp;

    if (graft == GraftType.hamstring && weeks < 12) {
      for (final item in work.uniqueItems) {
        final exercise = ExerciseCatalog.byId(item.exerciseId);
        if (exercise?.purpose != TrainingPurpose.hamstringStrength) continue;
        if ((exercise!.criteriaRequired.minimumWeeksForHamstringGraft ?? 0) >=
            12) {
          work.remove(item.exerciseId);
          check.changes.add(
            'Removed ${exercise.name}: resisted hamstring work waits until week 12 for a hamstring graft.',
          );
        } else if (item.prescription.sets > 2) {
          work.replace(
            item.exerciseId,
            item.copyWith(prescription: item.prescription.copyWith(sets: 2)),
          );
          check.changes.add(
            '${exercise.name} limited to 2 sets to protect the hamstring graft site.',
          );
        }
      }
    }
    if (graft == GraftType.allograft && weeks < 24) {
      for (final item in work.uniqueItems) {
        final exercise = ExerciseCatalog.byId(item.exerciseId);
        if (exercise?.purpose == TrainingPurpose.plyometric) {
          work.remove(item.exerciseId);
          check.changes.add(
            'Removed ${exercise!.name}: single-leg hopping waits until about 6 months with an allograft.',
          );
        }
      }
    }
    check.passDetail = switch (graft) {
      GraftType.hamstring when weeks < 12 =>
        'Hamstring loading stays unresisted and low-volume before week 12.',
      _ => 'No conflicts with ${graft.label} graft precautions.',
    };
    return check;
  }

  static _Check _equipment(_Draft work, PlanContext context) {
    final check = _Check('equipment', 'Matches your equipment');
    for (final item in work.uniqueItems) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise == null || context.hasEquipment(exercise)) continue;
      final replacement = _replaceOrRemove(
        work,
        context,
        item,
        context.hasEquipment,
      );
      final missing = exercise
          .missingEquipment(context.profile)
          .map((item) => item.label.toLowerCase())
          .join(' and ');
      if (replacement == null) {
        work.note(
          exercise.purpose.label,
          '${exercise.name} needs $missing. Add it in Training setup to include this.',
        );
      }
      check.changes.add(
        replacement == null
            ? 'Removed ${exercise.name} (needs $missing).'
            : 'Swapped ${exercise.name} for $replacement (no $missing).',
      );
    }
    final swapped = work.items.any((item) => item.substitutedFromId != null);
    check.passDetail = swapped
        ? 'Every exercise fits your equipment. Exercises that needed items you '
              'do not have were swapped for same-goal options.'
        : 'Every exercise can be done with the equipment you listed.';
    return check;
  }

  static _Check _goal(_Draft work, PlanContext context) {
    final check = _Check('goal', 'Consistent with your goal');
    for (final item in work.uniqueItems) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise == null || context.allowedByGoal(exercise.purpose)) continue;
      work.remove(item.exerciseId);
      check.changes.add(
        'Removed ${exercise.name}: not needed for ${context.profile.goal.label.toLowerCase()}.',
      );
    }
    check.passDetail =
        'No drills conflict with your goal (${context.profile.goalSummary.toLowerCase()}).';
    return check;
  }

  static DifficultyLevel _difficultyCap(PlanContext context) {
    final base = switch (context.phase) {
      RehabPhase.protectionAndMotion => DifficultyLevel.foundation,
      RehabPhase.earlyStrengthening => DifficultyLevel.moderate,
      RehabPhase.advancedStrength => DifficultyLevel.advanced,
      RehabPhase.neuromuscularControl => DifficultyLevel.advanced,
      RehabPhase.returnToSport => DifficultyLevel.sport,
    };
    if (context.status.symptomsElevated &&
        base.index > DifficultyLevel.foundation.index) {
      return context.phase == RehabPhase.earlyStrengthening
          ? DifficultyLevel.foundation
          : DifficultyLevel.moderate;
    }
    return base;
  }

  static _Check _difficulty(_Draft work, PlanContext context) {
    final check = _Check('difficulty', 'Difficulty fits your current level');
    final cap = _difficultyCap(context);
    for (final item in work.uniqueItems) {
      final exercise = ExerciseCatalog.byId(item.exerciseId);
      if (exercise == null || exercise.difficultyLevel.index <= cap.index) {
        continue;
      }
      final replacement = _replaceOrRemove(
        work,
        context,
        item,
        (candidate) =>
            candidate.difficultyLevel.index <= cap.index &&
            context.hasEquipment(candidate),
      );
      check.changes.add(
        replacement == null
            ? 'Removed ${exercise.name}: harder than ${cap.label.toLowerCase()} level.'
            : 'Replaced ${exercise.name} with the easier $replacement.',
      );
    }
    check.passDetail =
        'All exercises are at or below ${cap.label.toLowerCase()} difficulty '
        'for ${context.phase.label}${context.status.symptomsElevated ? ' with current symptoms' : ''}.';
    return check;
  }

  static _Check _duplicates(_Draft work) {
    final check = _Check('duplicates', 'No repeated or overlapping exercises');
    for (final session in work.sessions) {
      final seen = <String>{};
      final before = session.items.length;
      session.items.retainWhere((item) => seen.add(item.exerciseId));
      if (session.items.length != before) {
        check.changes.add('Removed a repeated exercise from ${session.name}.');
      }
      final byPurpose = <TrainingPurpose, List<PlanExercise>>{};
      for (final item in session.items) {
        final purpose = ExerciseCatalog.byId(item.exerciseId)?.purpose;
        if (purpose != null) byPurpose.putIfAbsent(purpose, () => []).add(item);
      }
      for (final entry in byPurpose.entries) {
        if (entry.value.length <= 2) continue;
        final sorted = [...entry.value]
          ..sort((a, b) => a.priority.compareTo(b.priority));
        for (final extra in sorted.take(entry.value.length - 2)) {
          session.items.remove(extra);
          check.changes.add(
            'Removed ${_name(extra.exerciseId)} from ${session.name}: '
            'more than two ${entry.key.label.toLowerCase()} exercises.',
          );
        }
      }
    }
    check.passDetail =
        'Each session has distinct exercises with no more than two per training goal.';
    return check;
  }

  static _Check _coverage(_Draft work, PlanContext context) {
    final check = _Check('coverage', 'Addresses your assessment results');
    var addressable = 0;
    for (final area in context.focusAreas) {
      final purposes = area.type.purposes.where(context.allowedByGoal).toSet();
      if (purposes.isEmpty) continue;
      addressable++;
      if (work.hasPurpose(purposes)) continue;

      PlanExercise? added;
      for (final purpose in purposes) {
        final selection = context.select(purpose, exclude: work.ids);
        if (selection == null) continue;
        added = context.toPlanExercise(
          selection,
          priority: area.priority.weight * 3,
          focus: area,
        );
        break;
      }
      if (added != null) {
        work.add(added);
        check.changes.add(
          'Added ${_name(added.exerciseId)} for "${area.title}".',
        );
      } else {
        final note = context.lockedNote(purposes.first);
        check.warnings.add(
          '"${area.title}" cannot be trained yet: ${note.detail}',
        );
      }
    }
    check.passDetail = addressable == 0
        ? 'No specific weaknesses were identified; the plan follows your phase.'
        : 'All $addressable trainable focus areas from your assessment have '
              'at least one matching exercise.';
    return check;
  }

  static _Check _balance(_Draft work, PlanContext context) {
    final check = _Check('balance', 'Balanced program');
    final groups = context.phase == RehabPhase.protectionAndMotion
        ? {
            'Motion': {
              TrainingPurpose.kneeExtension,
              TrainingPurpose.kneeFlexion,
            },
            'Quadriceps activation': {TrainingPurpose.quadActivation},
          }
        : {
            'Knee-dominant strength': {
              TrainingPurpose.quadStrength,
              TrainingPurpose.singleLegStrength,
            },
            'Hip-dominant strength': {
              TrainingPurpose.posteriorChain,
              TrainingPurpose.hamstringStrength,
              TrainingPurpose.hipStability,
            },
            'Balance or landing control': {
              TrainingPurpose.balance,
              TrainingPurpose.landing,
            },
          };
    for (final entry in groups.entries) {
      if (work.hasPurpose(entry.value)) continue;
      PlanExercise? added;
      for (final purpose in entry.value) {
        if (!context.allowedByGoal(purpose)) continue;
        final selection = context.select(purpose, exclude: work.ids);
        if (selection == null) continue;
        added = context.toPlanExercise(selection, priority: 5);
        break;
      }
      if (added != null) {
        work.add(added);
        check.changes.add(
          'Added ${_name(added.exerciseId)} so the plan includes ${entry.key.toLowerCase()}.',
        );
      } else {
        check.warnings.add(
          'No ${entry.key.toLowerCase()} exercise is available yet.',
        );
      }
    }

    // Merge a session that is too thin to stand on its own.
    if (work.sessions.length > 1 &&
        work.sessions.any((session) => session.items.length < 2)) {
      final merged = work.sessions.expand((session) => session.items).toList();
      final seen = <String>{};
      work.sessions
        ..clear()
        ..add(
          _MutableSession('A', 'Session A', [
            for (final item in merged)
              if (seen.add(item.exerciseId)) item,
          ]),
        );
      check.changes.add('Combined sessions so each one has enough work.');
    }
    check.passDetail = context.phase == RehabPhase.protectionAndMotion
        ? 'Includes motion work and quadriceps activation.'
        : 'Includes knee-dominant, hip-dominant, and balance or landing work.';
    return check;
  }

  static _Check _symptomProgression(_Draft work, PlanContext context) {
    final check = _Check('progression', 'Progression matches your symptoms');
    if (context.status.symptomsElevated) {
      for (final session in work.sessions) {
        for (var i = 0; i < session.items.length; i++) {
          final item = session.items[i];
          final level = item.prescription.level;
          if (level <= 0 || item.prescription.paused) continue;
          session.items[i] = item.copyWith(
            prescription: item.prescription.copyWith(
              sets: (item.prescription.sets - level).clamp(1, 6),
              paused: true,
            ),
          );
          check.changes.add(
            'Paused progression on ${_name(item.exerciseId)} while pain or swelling is elevated.',
          );
        }
      }
    }
    final progressed = work.uniqueItems
        .where(
          (item) => item.prescription.level > 0 && !item.prescription.paused,
        )
        .length;
    final regressed = work.uniqueItems
        .where((item) => item.prescription.level < 0)
        .length;
    check.passDetail = progressed + regressed == 0
        ? 'Starting doses are used; they adapt as you log feedback.'
        : 'Doses reflect your feedback: $progressed progressed, $regressed eased.';
    return check;
  }

  static _Check _timeBudget(_Draft work, PlanContext context) {
    final check = _Check('time', 'Fits your session length');
    final limit = context.profile.minutesPerSession + 3;

    for (final session in work.sessions) {
      final start = session.minutes;
      final dropped = <String>[];
      var trimmedSets = false;
      while (session.minutes > limit) {
        final reducible =
            session.items
                .where(
                  (item) =>
                      item.priority < PlanGenerator.criticalPriority &&
                      item.prescription.sets > 2,
                )
                .toList()
              ..sort((a, b) => a.priority.compareTo(b.priority));
        if (reducible.isNotEmpty) {
          final item = reducible.first;
          final index = session.items.indexOf(item);
          session.items[index] = item.copyWith(
            prescription: item.prescription.copyWith(
              sets: item.prescription.sets - 1,
            ),
          );
          trimmedSets = true;
          continue;
        }
        final removable =
            session.items
                .where(
                  (item) =>
                      item.priority < PlanGenerator.criticalPriority &&
                      !_isLastCoverage(work, item),
                )
                .toList()
              ..sort((a, b) => a.priority.compareTo(b.priority));
        if (removable.isEmpty || session.items.length <= 2) break;
        session.items.remove(removable.first);
        dropped.add(_name(removable.first.exerciseId));
      }
      if (dropped.isNotEmpty) {
        work.note(
          'Left out to fit your time',
          '${dropped.join(', ')} ${dropped.length == 1 ? 'was' : 'were'} left '
              'out of ${session.name} to keep it near '
              '${context.profile.minutesPerSession} minutes.',
        );
      }
      if (dropped.isNotEmpty || trimmedSets) {
        check.changes.add(
          '${session.name} shortened from about $start to ${session.minutes} min'
          '${dropped.isEmpty ? ' by trimming sets' : ' (left out ${dropped.join(', ')})'}.',
        );
      }
      if (session.minutes > limit) {
        check.warnings.add(
          '${session.name} still needs about ${session.minutes} min. Longer '
          'sessions would fit the essentials more comfortably.',
        );
      }
    }
    final summary = work.sessions
        .map((session) => '${session.name} about ${session.minutes} min')
        .join(', ');
    check.passDetail =
        '$summary (you have ${context.profile.minutesPerSession} min).';
    return check;
  }

  /// Whether removing [item] would leave one of its focus areas untrained.
  static bool _isLastCoverage(_Draft work, PlanExercise item) {
    final focus = item.focus;
    if (focus == null) return false;
    final purposes = focus.purposes;
    return !work.items.any(
      (other) =>
          other.exerciseId != item.exerciseId &&
          purposes.contains(ExerciseCatalog.byId(other.exerciseId)?.purpose),
    );
  }

  static _Check _weeklyLoad(_Draft work, PlanContext context) {
    final check = _Check('weekly', 'Realistic weekly load');
    final requested = context.profile.sessionsPerWeek;
    if (context.phase != RehabPhase.protectionAndMotion && requested > 4) {
      // Later repair passes start from the already-capped plan; only the
      // first pass reports the change.
      final alreadyCapped = work.sessionsPerWeek <= 4;
      work.sessionsPerWeek = 4;
      work.lightDays = requested - 4;
      if (!alreadyCapped) {
        final extra = requested - 4;
        check.changes.add(
          'Strength training is capped at 4 days a week so tissues recover; '
          'your other $extra ${extra == 1 ? 'day becomes a light day' : 'days become light days'}.',
        );
      }
    }

    final impactIds = work.items
        .where(
          (item) => ExerciseCatalog.byId(item.exerciseId)?.isHighImpact == true,
        )
        .map((item) => item.exerciseId)
        .toSet();
    if (impactIds.isNotEmpty &&
        work.sessions.length == 1 &&
        work.sessionsPerWeek >= 4) {
      final base = work.sessions.first;
      final withoutImpact = base.items
          .where((item) => !impactIds.contains(item.exerciseId))
          .toList();
      if (withoutImpact.length >= 2) {
        work.sessions.add(_MutableSession('B', 'Session B', withoutImpact));
        check.changes.add(
          'Impact drills moved to Session A only so they never fall on back-to-back days.',
        );
      }
    } else if (impactIds.length > 2 * work.sessions.length) {
      check.warnings.add(
        'This plan has several impact drills. Stop if the knee swells the next day.',
      );
    }
    check.passDetail = context.phase == RehabPhase.protectionAndMotion
        ? '${work.sessionsPerWeek} sessions a week, plus daily motion work on other days.'
        : '${work.sessionsPerWeek} training days a week with recovery between harder sessions.';
    return check;
  }

  static _Check _consistency(PlanContext context) {
    final check = _Check('answers', 'Answers are consistent');
    for (final issue in context.consistency) {
      check.warnings.add('${issue.message} ${issue.resolution}');
    }
    check.passDetail = 'No conflicting assessment answers were found.';
    return check;
  }

  static _Check _clinicalFlags(PlanContext context) {
    final check = _Check('clinical', 'Clinical safety flags');
    for (final flag in context.evaluation.safetyFlags) {
      check.warnings.add(flag);
    }
    if (check.warnings.isNotEmpty) {
      check.warnings.add(
        'The plan is limited to protected motion work until you have been reviewed.',
      );
    }
    check.passDetail = 'No instability, locking, or giving way was reported.';
    return check;
  }

  static _Check _notEmpty(_Draft work, PlanContext context) {
    final check = _Check('content', 'Plan has enough to do');
    final count = work.ids.length;
    if (count == 0) {
      check.warnings.add(
        'No exercise is unlocked yet. Review the phase blockers with your clinical team.',
      );
    } else if (count < 3) {
      check.warnings.add(
        'Only $count ${count == 1 ? 'exercise is' : 'exercises are'} unlocked right now; '
        'more unlock as your criteria improve.',
      );
    }
    check.passDetail =
        '$count exercises across ${work.sessions.length} '
        '${work.sessions.length == 1 ? 'session' : 'sessions'}.';
    return check;
  }
}
