import 'package:acl_rehab/core/utils/phase_logic.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rehabilitation phase assignment', () {
    test(
      'assigns Phase 1 when symptoms and restrictions indicate protection',
      () {
        final assessment = Assessment(
          surgeryDate: DateTime(2026, 6, 1),
          graftType: GraftType.hamstring,
          pain: 5,
          swelling: Swelling.mild,
          canStraighten: false,
          canBend: false,
          weightBearing: WeightBearing.partial,
          walkingQuality: WalkingQuality.painful,
          instability: false,
          locking: false,
          givingWay: false,
          restrictions: const ['No Running', 'Brace Required'],
          notes: 'Needs careful progression',
        );

        expect(assignRehabPhase(assessment), RehabPhase.protectionAndMotion);
      },
    );

    test('does not assign Phase 1 for a quiet knee at 29 weeks', () {
      final assessment = Assessment(
        surgeryDate: DateTime.now().subtract(const Duration(days: 7 * 29)),
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
        notes: 'Ready for return to sport',
      );

      expect(assignRehabPhase(assessment), RehabPhase.neuromuscularControl);
    });

    test('assigns Phase 4 for objective return-to-sport criteria', () {
      final assessment = Assessment(
        surgeryDate: DateTime.now().subtract(const Duration(days: 7 * 30)),
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
        notes: 'Objective testing passed',
        protocolReadiness: const ProtocolReadiness(
          readinessCompleted: true,
          straightLegRaiseNoLag: true,
          strongQuadSet: true,
          noPainOrSwellingAfterExercise: true,
          flexionNearOtherSide: true,
          singleLegSquatTenReps: true,
          dropJumpGoodControl: true,
          completedJogRunProgram: true,
          painFreeLoadingActivities: true,
          painFreeRepeatedSingleLegHops: true,
          quadStrengthSymmetry: 92,
          hamstringStrengthSymmetry: 92,
          gluteStrengthSymmetry: 92,
          balanceSymmetry: 92,
          hopTestSymmetry: 92,
          koosSportsScore: 92,
          ikdcScore: 94,
          aclRsiScore: 92,
          ptClearedForRunning: true,
          mdClearedForSport: true,
        ),
      );

      expect(assignRehabPhase(assessment), RehabPhase.returnToSport);
    });

    test('keeps return-to-sport drills gated when running is restricted', () {
      final assessment = Assessment(
        surgeryDate: DateTime.now().subtract(const Duration(days: 7 * 30)),
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
        restrictions: const ['No Running'],
        notes: 'Running not cleared',
      );

      expect(assignRehabPhase(assessment), RehabPhase.neuromuscularControl);
    });
  });
}
