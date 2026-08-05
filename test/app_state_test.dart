import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('latest milestone only uses check-ins after the current assessment', () {
    final assessmentUpdatedAt = DateTime(2026, 8, 5, 12);
    final oldCheckIn = _checkIn(
      id: 'old',
      createdAt: DateTime(2026, 8, 1),
      pain: 5,
    );
    final activeCheckIn = _checkIn(
      id: 'active',
      createdAt: DateTime(2026, 8, 6),
      pain: 1,
    );

    final state = AppState(
      assessment: _assessment(),
      assessmentUpdatedAt: assessmentUpdatedAt,
      milestoneCheckIns: [oldCheckIn, activeCheckIn],
    );

    expect(state.activeMilestoneCheckIns, [activeCheckIn]);
    expect(state.latestMilestone, activeCheckIn);
  });
}

Assessment _assessment() {
  return Assessment(
    surgeryDate: DateTime(2026, 1, 15),
    graftType: GraftType.hamstring,
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
}

MilestoneCheckIn _checkIn({
  required String id,
  required DateTime createdAt,
  required int pain,
}) {
  return MilestoneCheckIn(
    id: id,
    createdAt: createdAt,
    pain: pain,
    swelling: Swelling.none,
    walkingQuality: WalkingQuality.normal,
    canRun: true,
    hasFullExtension: true,
    hasFunctionalFlexion: true,
    confidence: 8,
    quadStrengthSymmetry: 90,
    hopTestSymmetry: 90,
    balanceSymmetry: 90,
    ptClearanceForSport: true,
  );
}
