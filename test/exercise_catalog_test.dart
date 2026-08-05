import 'package:acl_rehab/data/exercise_catalog.dart';
import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final earlyStrengthAssessment = Assessment(
    surgeryDate: DateTime.now().subtract(const Duration(days: 7 * 7)),
    graftType: GraftType.patellarTendon,
    pain: 1,
    swelling: Swelling.none,
    canStraighten: true,
    canBend: true,
    weightBearing: WeightBearing.full,
    walkingQuality: WalkingQuality.normal,
    instability: false,
    locking: false,
    givingWay: false,
    restrictions: const [],
    notes: '',
  );

  group('Exercise catalog session planning', () {
    test('builds a session from the requested phase only', () {
      final session = ExerciseCatalog.sessionFor(
        earlyStrengthAssessment,
        milestone: null,
        phase: RehabPhase.earlyStrengthening,
      );

      expect(session, isNotEmpty);
      expect(
        session.every(
          (exercise) => exercise.phase == RehabPhase.earlyStrengthening,
        ),
        isTrue,
      );
    });

    test('includes no more than one exercise per session block', () {
      final session = ExerciseCatalog.sessionFor(
        earlyStrengthAssessment,
        milestone: null,
        phase: RehabPhase.earlyStrengthening,
      );

      expect(
        session.map((exercise) => exercise.sessionBlock).toSet().length,
        session.length,
      );
    });

    test('alternatives preserve the phase and session block', () {
      final boxSquat = ExerciseCatalog.byId('box-squat')!;
      final alternatives = ExerciseCatalog.alternativesFor(
        boxSquat,
        earlyStrengthAssessment,
        milestone: null,
      );

      expect(alternatives, isNotEmpty);
      expect(
        alternatives.every(
          (exercise) =>
              exercise.phase == boxSquat.phase &&
              exercise.sessionBlock == boxSquat.sessionBlock,
        ),
        isTrue,
      );
    });

    test('a current check-in can unlock the current-phase session plan', () {
      final assessment = Assessment(
        surgeryDate: DateTime.now().subtract(const Duration(days: 7 * 29)),
        graftType: GraftType.patellarTendon,
        pain: 6,
        swelling: Swelling.moderate,
        canStraighten: false,
        canBend: false,
        weightBearing: WeightBearing.full,
        walkingQuality: WalkingQuality.painful,
        instability: false,
        locking: false,
        givingWay: false,
        restrictions: const [],
        notes: '',
      );
      final checkIn = MilestoneCheckIn(
        id: 'current-check-in',
        createdAt: DateTime.now(),
        pain: 0,
        swelling: Swelling.none,
        walkingQuality: WalkingQuality.normal,
        canRun: true,
        hasFullExtension: true,
        hasFunctionalFlexion: true,
        confidence: 8,
        quadStrengthSymmetry: 85,
        hamstringStrengthSymmetry: 85,
        hipStrengthSymmetry: 85,
        hopTestSymmetry: 85,
        balanceSymmetry: 85,
        painFreeLoadingActivities: true,
        painFreeRepeatedSingleLegHops: true,
        canPerformControlledSingleLegSquat: true,
        goodLandingControl: true,
        completedJogRunProgram: true,
        ptClearanceForRunning: true,
        ptClearanceForSport: false,
      );

      final phase = evaluateRehabPhase(assessment, milestone: checkIn).phase;
      final session = ExerciseCatalog.sessionFor(
        assessment,
        milestone: checkIn,
        phase: phase,
      );

      expect(phase, RehabPhase.neuromuscularControl);
      expect(session, isNotEmpty);
      expect(
        session.every(
          (exercise) => exercise.phase == RehabPhase.neuromuscularControl,
        ),
        isTrue,
      );
    });
  });
}
