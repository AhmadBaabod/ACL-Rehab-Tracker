import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';

/// Readiness for a patient who has completed early criteria and tolerates
/// loading, with the given measured symmetry values (0 = not measured).
ProtocolReadiness loadingReadiness({
  int quad = 0,
  int hamstring = 0,
  int hip = 0,
  int balance = 0,
  int hop = 0,
}) {
  return ProtocolReadiness(
    readinessCompleted: true,
    straightLegRaiseNoLag: true,
    strongQuadSet: true,
    noPainOrSwellingAfterExercise: true,
    flexionNearOtherSide: true,
    painFreeLoadingActivities: true,
    quadStrengthSymmetry: quad,
    hamstringStrengthSymmetry: hamstring,
    gluteStrengthSymmetry: hip,
    balanceSymmetry: balance,
    hopTestSymmetry: hop,
  );
}

/// Every return-to-sport criterion met.
const returnToSportReadiness = ProtocolReadiness(
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
);

TrainingProfile fullGym({
  RecoveryGoal goal = RecoveryGoal.returnToSport,
  int sessions = 3,
  int minutes = 45,
}) {
  return TrainingProfile(
    goal: goal,
    sessionsPerWeek: sessions,
    minutesPerSession: minutes,
    equipment: EquipmentType.values.toSet(),
  );
}

Assessment testAssessment({
  required int weeks,
  GraftType graft = GraftType.patellarTendon,
  int pain = 1,
  Swelling swelling = Swelling.none,
  bool extension = true,
  bool flexion = true,
  WeightBearing weightBearing = WeightBearing.full,
  WalkingQuality walking = WalkingQuality.normal,
  bool instability = false,
  List<String> restrictions = const [],
  ProtocolReadiness readiness = const ProtocolReadiness(
    readinessCompleted: true,
  ),
  int confidence = 6,
  TrainingProfile profile = const TrainingProfile(),
}) {
  return Assessment(
    surgeryDate: DateTime.now().subtract(Duration(days: weeks * 7 + 1)),
    graftType: graft,
    pain: pain,
    swelling: swelling,
    canStraighten: extension,
    canBend: flexion,
    weightBearing: weightBearing,
    walkingQuality: walking,
    instability: instability,
    locking: false,
    givingWay: false,
    restrictions: restrictions,
    notes: '',
    protocolReadiness: readiness,
    confidence: confidence,
    profile: profile,
  );
}
