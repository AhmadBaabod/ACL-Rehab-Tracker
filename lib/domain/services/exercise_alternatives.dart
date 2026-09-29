import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/exercise.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';

enum AlternativeRelation { easier, similar, harder }

extension AlternativeRelationX on AlternativeRelation {
  String get label {
    switch (this) {
      case AlternativeRelation.easier:
        return 'Easier';
      case AlternativeRelation.similar:
        return 'Similar';
      case AlternativeRelation.harder:
        return 'Harder';
    }
  }
}

class ExerciseAlternative {
  const ExerciseAlternative({
    required this.exercise,
    required this.relation,
    required this.samePurpose,
    required this.reasons,
    required this.blockers,
  });

  final Exercise exercise;
  final AlternativeRelation relation;

  /// False when the alternative trains a closely related quality instead of
  /// the exact same one.
  final bool samePurpose;

  /// Why this is a valid replacement.
  final List<String> reasons;

  /// Why it cannot be used right now (missing equipment or unmet criteria).
  final List<String> blockers;

  bool get isAvailable => blockers.isEmpty;
}

/// Finds replacements that serve the same training purpose as an exercise,
/// respecting the user's phase, unlock criteria, restrictions, and equipment.
class AlternativeFinder {
  const AlternativeFinder._();

  static int _difficultyRank(Exercise exercise) =>
      exercise.difficultyLevel.index * 10 + exercise.phase.order;

  static AlternativeRelation relationOf(Exercise original, Exercise candidate) {
    final delta = _difficultyRank(candidate) - _difficultyRank(original);
    if (delta == 0) return AlternativeRelation.similar;
    return delta < 0 ? AlternativeRelation.easier : AlternativeRelation.harder;
  }

  static List<ExerciseAlternative> find(
    Exercise exercise, {
    required Assessment assessment,
    required MilestoneCheckIn? milestone,
    required RehabPhase currentPhase,
    TrainingProfile? profile,
    bool includeUnavailable = true,
    int limit = 6,
  }) {
    final userProfile = profile ?? assessment.profile;
    final maxPhase = currentPhase.order > exercise.phase.order
        ? currentPhase.order
        : exercise.phase.order;

    ExerciseAlternative? evaluate(Exercise candidate, {required bool same}) {
      if (candidate.id == exercise.id) return null;
      if (candidate.phase.order > maxPhase) return null;

      final unlock = candidate.unlockStatus(assessment, milestone);
      final missing = candidate.missingEquipment(userProfile);
      final blockers = [
        if (missing.isNotEmpty)
          'Needs ${missing.map((item) => item.label.toLowerCase()).join(' and ')}',
        ...unlock.reasons.take(2),
      ];
      if (!includeUnavailable && blockers.isNotEmpty) return null;

      final relation = relationOf(exercise, candidate);
      final overlap = candidate.targetMuscles
          .where(exercise.targetMuscles.contains)
          .toList();
      final reasons = <String>[
        same
            ? 'Same goal: ${exercise.purpose.label.toLowerCase()}'
            : 'Related goal: ${candidate.purpose.label.toLowerCase()}',
        if (overlap.isNotEmpty)
          'Works ${overlap.take(3).join(', ').toLowerCase()}',
        // Emphasize the equipment difference when the original needs some.
        if (candidate.needsNoEquipment)
          exercise.requiredEquipment.isNotEmpty
              ? 'No special equipment needed'
              : 'Household items only'
        else
          'Uses ${candidate.requiredEquipment.map((item) => item.label.toLowerCase()).join(' and ')}',
        switch (relation) {
          AlternativeRelation.easier =>
            'Easier option (${candidate.difficultyLevel.label.toLowerCase()})',
          AlternativeRelation.harder =>
            'Harder progression (${candidate.difficultyLevel.label.toLowerCase()})',
          AlternativeRelation.similar => 'Similar difficulty',
        },
      ];

      return ExerciseAlternative(
        exercise: candidate,
        relation: relation,
        samePurpose: same,
        reasons: reasons,
        blockers: blockers,
      );
    }

    final same = ExerciseCatalog.all
        .where((candidate) => candidate.purpose == exercise.purpose)
        .map((candidate) => evaluate(candidate, same: true))
        .whereType<ExerciseAlternative>()
        .toList();

    final availableSame = same.where((item) => item.isAvailable).length;
    final related = availableSame >= 2
        ? <ExerciseAlternative>[]
        : ExerciseCatalog.all
              .where(
                (candidate) =>
                    exercise.purpose.related.contains(candidate.purpose),
              )
              .map((candidate) => evaluate(candidate, same: false))
              .whereType<ExerciseAlternative>()
              .where((item) => item.isAvailable)
              .toList();

    int score(ExerciseAlternative item) {
      var value = 0;
      if (item.isAvailable) value += 1000;
      if (item.samePurpose) value += 500;
      if (exercise.alternativeExerciseIds.contains(item.exercise.id)) {
        value += 60;
      }
      value += switch (item.relation) {
        AlternativeRelation.similar => 50,
        AlternativeRelation.easier => 40,
        AlternativeRelation.harder => 30,
      };
      value +=
          item.exercise.targetMuscles
              .where(exercise.targetMuscles.contains)
              .length *
          5;
      // Prefer options closest to the current phase.
      value -= (currentPhase.order - item.exercise.phase.order).abs() * 8;
      return value;
    }

    final all = [...same, ...related]
      ..sort((a, b) => score(b).compareTo(score(a)));
    return all.take(limit).toList();
  }
}
