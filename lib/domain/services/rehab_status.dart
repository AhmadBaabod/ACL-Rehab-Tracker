import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';

/// The user's current clinical picture: the active assessment overlaid with
/// the latest milestone check-in, using the same precedence as the phase and
/// exercise-unlock rules. Measured scores of 0 are treated as "not measured".
class RehabStatus {
  const RehabStatus({
    required this.weeksPostOp,
    required this.graftType,
    required this.pain,
    required this.swelling,
    required this.fullExtension,
    required this.functionalFlexion,
    required this.weightBearing,
    required this.walking,
    required this.mechanicalSymptoms,
    required this.confidence,
    required this.readinessKnown,
    required this.straightLegRaiseNoLag,
    required this.strongQuadSet,
    required this.painFreeLoading,
    required this.controlledSingleLegSquat,
    required this.goodLandingControl,
    required this.painFreeRepeatedHops,
    required this.completedJogRunProgram,
    required this.ptClearedForRunning,
    required this.physicianClearedForSport,
    required this.restrictions,
    this.quadSymmetry,
    this.hamstringSymmetry,
    this.hipSymmetry,
    this.balanceSymmetry,
    this.hopSymmetry,
    this.koosSports,
    this.ikdc,
    this.aclRsi,
  });

  factory RehabStatus.from(
    Assessment assessment, {
    MilestoneCheckIn? milestone,
  }) {
    final protocol = assessment.protocolReadiness;
    int? measured(int? value) => value == null || value <= 0 ? null : value;

    return RehabStatus(
      weeksPostOp: assessment.weeksPostOp,
      graftType: assessment.graftType,
      pain: milestone?.pain ?? assessment.pain,
      swelling: milestone?.swelling ?? assessment.swelling,
      fullExtension: milestone?.hasFullExtension ?? assessment.canStraighten,
      functionalFlexion:
          milestone?.hasFunctionalFlexion ??
          (assessment.canBend &&
              (!protocol.readinessCompleted || protocol.flexionNearOtherSide)),
      weightBearing: milestone?.weightBearing ?? assessment.weightBearing,
      walking: milestone?.walkingQuality ?? assessment.walkingQuality,
      mechanicalSymptoms: assessment.hasMechanicalSymptoms,
      confidence: milestone?.confidence ?? assessment.confidence,
      readinessKnown:
          protocol.readinessCompleted ||
          milestone?.hasSessionReadinessData == true,
      straightLegRaiseNoLag: protocol.straightLegRaiseNoLag,
      strongQuadSet: protocol.strongQuadSet,
      painFreeLoading:
          milestone?.painFreeLoadingActivities ??
          protocol.painFreeLoadingActivities,
      controlledSingleLegSquat:
          milestone?.canPerformControlledSingleLegSquat ??
          protocol.singleLegSquatTenReps,
      goodLandingControl:
          milestone?.goodLandingControl ?? protocol.dropJumpGoodControl,
      painFreeRepeatedHops:
          milestone?.painFreeRepeatedSingleLegHops ??
          protocol.painFreeRepeatedSingleLegHops,
      completedJogRunProgram:
          milestone?.completedJogRunProgram ?? protocol.completedJogRunProgram,
      ptClearedForRunning:
          milestone?.ptClearanceForRunning ?? protocol.ptClearedForRunning,
      physicianClearedForSport:
          milestone?.physicianClearanceForSport ?? protocol.mdClearedForSport,
      restrictions: assessment.restrictions,
      quadSymmetry: measured(
        milestone?.quadStrengthSymmetry ?? protocol.quadStrengthSymmetry,
      ),
      hamstringSymmetry: measured(
        milestone?.hamstringStrengthSymmetry ??
            protocol.hamstringStrengthSymmetry,
      ),
      hipSymmetry: measured(
        milestone?.hipStrengthSymmetry ?? protocol.gluteStrengthSymmetry,
      ),
      balanceSymmetry: measured(
        milestone?.balanceSymmetry ?? protocol.balanceSymmetry,
      ),
      hopSymmetry: measured(
        milestone?.hopTestSymmetry ?? protocol.hopTestSymmetry,
      ),
      koosSports: measured(
        milestone?.koosSportsScore ?? protocol.koosSportsScore,
      ),
      ikdc: measured(milestone?.ikdcScore ?? protocol.ikdcScore),
      aclRsi: measured(milestone?.aclRsiScore ?? protocol.aclRsiScore),
    );
  }

  final int weeksPostOp;
  final GraftType graftType;
  final int pain;
  final Swelling swelling;
  final bool fullExtension;
  final bool functionalFlexion;
  final WeightBearing weightBearing;
  final WalkingQuality walking;
  final bool mechanicalSymptoms;
  final int confidence;
  final bool readinessKnown;
  final bool straightLegRaiseNoLag;
  final bool strongQuadSet;
  final bool painFreeLoading;
  final bool controlledSingleLegSquat;
  final bool goodLandingControl;
  final bool painFreeRepeatedHops;
  final bool completedJogRunProgram;
  final bool ptClearedForRunning;
  final bool physicianClearedForSport;
  final List<String> restrictions;
  final int? quadSymmetry;
  final int? hamstringSymmetry;
  final int? hipSymmetry;
  final int? balanceSymmetry;
  final int? hopSymmetry;
  final int? koosSports;
  final int? ikdc;
  final int? aclRsi;

  bool get quietKnee => pain <= 2 && swelling == Swelling.none;

  /// Symptoms that call for lower volume and easier variations.
  bool get symptomsElevated =>
      pain >= 4 || swelling.severity >= Swelling.moderate.severity;

  /// Symptoms that call for easy effort but not a volume change.
  bool get symptomsMild =>
      !symptomsElevated && (pain >= 3 || swelling != Swelling.none);

  bool get fullWeightBearing => weightBearing == WeightBearing.full;

  bool get normalWalking => walking == WalkingQuality.normal;

  bool hasRestriction(String value) =>
      restrictions.any((item) => item.toLowerCase() == value.toLowerCase());
}
