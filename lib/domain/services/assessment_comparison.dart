import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/services/exercise_alternatives.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';

enum ChangeDirection { improved, declined, unchanged, newlyMeasured }

class MetricChange {
  const MetricChange({
    required this.label,
    required this.before,
    required this.after,
    required this.direction,
  });

  final String label;
  final String before;
  final String after;
  final ChangeDirection direction;
}

class ExerciseChange {
  const ExerciseChange({required this.title, required this.detail});

  final String title;
  final String detail;
}

class PlanDiff {
  const PlanDiff({
    required this.added,
    required this.removed,
    required this.swapped,
    required this.doseChanges,
    required this.unchanged,
  });

  final List<String> added;
  final List<String> removed;
  final List<ExerciseChange> swapped;
  final List<ExerciseChange> doseChanges;
  final int unchanged;

  bool get isEmpty =>
      added.isEmpty &&
      removed.isEmpty &&
      swapped.isEmpty &&
      doseChanges.isEmpty;

  int get changeCount =>
      added.length + removed.length + swapped.length + doseChanges.length;

  String get summary {
    if (isEmpty) return 'No exercise changes.';
    final parts = [
      if (swapped.isNotEmpty) '${swapped.length} swapped',
      if (added.isNotEmpty) '${added.length} added',
      if (removed.isNotEmpty) '${removed.length} removed',
      if (doseChanges.isNotEmpty) '${doseChanges.length} re-dosed',
    ];
    return parts.join(', ');
  }

  static PlanDiff between(RehabPlan? previous, RehabPlan next) {
    final before = {
      for (final item in previous?.allExercises ?? const <PlanExercise>[])
        item.exerciseId: item,
    };
    final after = {for (final item in next.allExercises) item.exerciseId: item};

    final removedIds = before.keys
        .where((id) => !after.containsKey(id))
        .toList();
    final addedIds = after.keys.where((id) => !before.containsKey(id)).toList();
    final swapped = <ExerciseChange>[];

    // Pair a removed and an added exercise with the same purpose as a swap.
    for (final removedId in [...removedIds]) {
      final old = ExerciseCatalog.byId(removedId);
      if (old == null) continue;
      final matchIndex = addedIds.indexWhere(
        (id) => ExerciseCatalog.byId(id)?.purpose == old.purpose,
      );
      if (matchIndex < 0) continue;
      final replacement = ExerciseCatalog.byId(addedIds[matchIndex])!;
      final relation = AlternativeFinder.relationOf(old, replacement);
      swapped.add(
        ExerciseChange(
          title: '${old.name} -> ${replacement.name}',
          detail: switch (relation) {
            AlternativeRelation.harder =>
              'Harder variation for ${old.purpose.label.toLowerCase()}.',
            AlternativeRelation.easier =>
              'Easier variation for ${old.purpose.label.toLowerCase()}.',
            AlternativeRelation.similar =>
              'Same-level option for ${old.purpose.label.toLowerCase()}.',
          },
        ),
      );
      removedIds.remove(removedId);
      addedIds.removeAt(matchIndex);
    }

    final doseChanges = <ExerciseChange>[];
    var unchanged = 0;
    for (final entry in after.entries) {
      final old = before[entry.key];
      if (old == null) continue;
      final oldSets = old.prescription.sets;
      final newSets = entry.value.prescription.sets;
      if (oldSets == newSets) {
        unchanged++;
        continue;
      }
      doseChanges.add(
        ExerciseChange(
          title: ExerciseCatalog.byId(entry.key)?.name ?? entry.key,
          detail:
              '$oldSets -> $newSets sets (${newSets > oldSets ? 'progressed' : 'eased'}).',
        ),
      );
    }

    String name(String id) => ExerciseCatalog.byId(id)?.name ?? id;
    return PlanDiff(
      added: addedIds.map(name).toList(),
      removed: removedIds.map(name).toList(),
      swapped: swapped,
      doseChanges: doseChanges,
      unchanged: unchanged,
    );
  }
}

class AssessmentComparison {
  const AssessmentComparison({
    required this.metrics,
    required this.previousPhase,
    required this.currentPhase,
    required this.planDiff,
    required this.remainingWeaknesses,
  });

  final List<MetricChange> metrics;
  final RehabPhase previousPhase;
  final RehabPhase currentPhase;
  final PlanDiff planDiff;

  /// Focus areas that the new plan still targets.
  final List<FocusArea> remainingWeaknesses;

  List<MetricChange> get improvements => metrics
      .where((item) => item.direction == ChangeDirection.improved)
      .toList();

  List<MetricChange> get declines => metrics
      .where((item) => item.direction == ChangeDirection.declined)
      .toList();

  List<MetricChange> get newlyMeasured => metrics
      .where((item) => item.direction == ChangeDirection.newlyMeasured)
      .toList();

  int get phaseDelta => currentPhase.order - previousPhase.order;

  static AssessmentComparison compare({
    required RehabStatus before,
    required RehabStatus after,
    required RehabPhase previousPhase,
    required RehabPhase currentPhase,
    required RehabPlan? previousPlan,
    required RehabPlan newPlan,
  }) {
    final metrics = <MetricChange>[];

    void lowerIsBetter(String label, int a, int b, String Function(int) show) {
      metrics.add(
        MetricChange(
          label: label,
          before: show(a),
          after: show(b),
          direction: b < a
              ? ChangeDirection.improved
              : b > a
              ? ChangeDirection.declined
              : ChangeDirection.unchanged,
        ),
      );
    }

    void flag(String label, bool a, bool b, String yes, String no) {
      metrics.add(
        MetricChange(
          label: label,
          before: a ? yes : no,
          after: b ? yes : no,
          direction: a == b
              ? ChangeDirection.unchanged
              : b
              ? ChangeDirection.improved
              : ChangeDirection.declined,
        ),
      );
    }

    void measured(String label, int? a, int? b, {String suffix = '%'}) {
      if (a == null && b == null) return;
      metrics.add(
        MetricChange(
          label: label,
          before: a == null ? 'Not measured' : '$a$suffix',
          after: b == null ? 'Not measured' : '$b$suffix',
          direction: a == null
              ? ChangeDirection.newlyMeasured
              : b == null
              ? ChangeDirection.unchanged
              : b - a >= 3
              ? ChangeDirection.improved
              : a - b >= 3
              ? ChangeDirection.declined
              : ChangeDirection.unchanged,
        ),
      );
    }

    lowerIsBetter('Pain', before.pain, after.pain, (value) => '$value/10');
    lowerIsBetter(
      'Swelling',
      before.swelling.severity,
      after.swelling.severity,
      (value) => Swelling.values[value].label,
    );
    flag(
      'Knee extension',
      before.fullExtension,
      after.fullExtension,
      'Full',
      'Limited',
    );
    flag(
      'Knee flexion',
      before.functionalFlexion,
      after.functionalFlexion,
      'Functional',
      'Limited',
    );
    flag(
      'Weight bearing',
      before.fullWeightBearing,
      after.fullWeightBearing,
      'Full',
      'Not full',
    );
    metrics.add(
      MetricChange(
        label: 'Walking',
        before: before.walking.label,
        after: after.walking.label,
        direction: after.walking.index < before.walking.index
            ? ChangeDirection.improved
            : after.walking.index > before.walking.index
            ? ChangeDirection.declined
            : ChangeDirection.unchanged,
      ),
    );
    flag(
      'Instability or locking',
      !before.mechanicalSymptoms,
      !after.mechanicalSymptoms,
      'None',
      'Reported',
    );
    metrics.add(
      MetricChange(
        label: 'Confidence',
        before: '${before.confidence}/10',
        after: '${after.confidence}/10',
        direction: after.confidence > before.confidence
            ? ChangeDirection.improved
            : after.confidence < before.confidence
            ? ChangeDirection.declined
            : ChangeDirection.unchanged,
      ),
    );
    flag(
      'Straight leg raise without lag',
      before.straightLegRaiseNoLag,
      after.straightLegRaiseNoLag,
      'Yes',
      'Not yet',
    );
    flag(
      'Pain-free loading',
      before.painFreeLoading,
      after.painFreeLoading,
      'Yes',
      'Not yet',
    );
    flag(
      'Single-leg squat control',
      before.controlledSingleLegSquat,
      after.controlledSingleLegSquat,
      'Yes',
      'Not yet',
    );
    flag(
      'Landing control',
      before.goodLandingControl,
      after.goodLandingControl,
      'Yes',
      'Not yet',
    );
    flag(
      'Running clearance',
      before.ptClearedForRunning,
      after.ptClearedForRunning,
      'Cleared',
      'Not yet',
    );
    measured('Quadriceps symmetry', before.quadSymmetry, after.quadSymmetry);
    measured(
      'Hamstring symmetry',
      before.hamstringSymmetry,
      after.hamstringSymmetry,
    );
    measured('Hip symmetry', before.hipSymmetry, after.hipSymmetry);
    measured('Balance symmetry', before.balanceSymmetry, after.balanceSymmetry);
    measured('Hop symmetry', before.hopSymmetry, after.hopSymmetry);
    measured('ACL-RSI', before.aclRsi, after.aclRsi, suffix: '');

    return AssessmentComparison(
      metrics: metrics,
      previousPhase: previousPhase,
      currentPhase: currentPhase,
      planDiff: PlanDiff.between(previousPlan, newPlan),
      remainingWeaknesses: newPlan.focusAreas,
    );
  }
}
