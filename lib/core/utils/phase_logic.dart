import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';

class PhaseEvaluation {
  const PhaseEvaluation({
    required this.phase,
    required this.progress,
    required this.goals,
    required this.blockers,
    required this.safetyFlags,
  });

  final RehabPhase phase;
  final double progress;
  final List<String> goals;
  final List<String> blockers;
  final List<String> safetyFlags;

  bool get needsClinicalReview => safetyFlags.isNotEmpty;
}

RehabPhase assignRehabPhase(Assessment assessment) {
  return evaluateRehabPhase(assessment).phase;
}

PhaseEvaluation evaluateRehabPhase(
  Assessment assessment, {
  MilestoneCheckIn? milestone,
}) {
  final blockers = <String>[];
  final safetyFlags = <String>[];
  final protocol = assessment.protocolReadiness;
  final readinessKnown =
      protocol.readinessCompleted || milestone?.hasSessionReadinessData == true;

  if (assessment.instability || assessment.givingWay) {
    safetyFlags.add(
      'Instability or giving way should be reviewed by your clinical team.',
    );
  }
  if (assessment.locking) {
    safetyFlags.add(
      'Locking can be a mechanical symptom and needs clinical review.',
    );
  }

  final latestPain = milestone?.pain ?? assessment.pain;
  final latestSwelling = milestone?.swelling ?? assessment.swelling;
  final latestWalking = milestone?.walkingQuality ?? assessment.walkingQuality;
  final latestQuadSymmetry =
      milestone?.quadStrengthSymmetry ?? protocol.quadStrengthSymmetry;
  final latestHamstringSymmetry =
      milestone?.hamstringStrengthSymmetry ??
      protocol.hamstringStrengthSymmetry;
  final latestHipSymmetry =
      milestone?.hipStrengthSymmetry ?? protocol.gluteStrengthSymmetry;
  final latestHopSymmetry =
      milestone?.hopTestSymmetry ?? protocol.hopTestSymmetry;
  final latestBalanceSymmetry =
      milestone?.balanceSymmetry ?? protocol.balanceSymmetry;
  final latestKoosSportsScore =
      milestone?.koosSportsScore ?? protocol.koosSportsScore;
  final latestIkdcScore = milestone?.ikdcScore ?? protocol.ikdcScore;
  final latestAclRsiScore = milestone?.aclRsiScore ?? protocol.aclRsiScore;
  final painFreeLoading =
      milestone?.painFreeLoadingActivities ??
      protocol.painFreeLoadingActivities;
  final painFreeRepeatedHops =
      milestone?.painFreeRepeatedSingleLegHops ??
      protocol.painFreeRepeatedSingleLegHops;
  final goodLandingControl =
      milestone?.goodLandingControl ?? protocol.dropJumpGoodControl;
  final controlledSingleLegSquat =
      milestone?.canPerformControlledSingleLegSquat ??
      protocol.singleLegSquatTenReps;
  final completedJogRunProgram =
      milestone?.completedJogRunProgram ?? protocol.completedJogRunProgram;
  final ptClearedForRunning =
      milestone?.ptClearanceForRunning ?? protocol.ptClearedForRunning;
  final physicianClearedForSport =
      milestone?.physicianClearanceForSport ?? protocol.mdClearedForSport;
  final hasFullExtension =
      milestone?.hasFullExtension ?? assessment.canStraighten;
  final hasFunctionalFlexion =
      milestone?.hasFunctionalFlexion ??
      (assessment.canBend &&
          (!readinessKnown || protocol.flexionNearOtherSide));
  final quietKnee =
      latestPain <= 2 &&
      latestSwelling == Swelling.none &&
      (!readinessKnown || painFreeLoading);
  final fullRom = hasFullExtension && hasFunctionalFlexion;
  final fullWeightBearing =
      (milestone?.weightBearing ?? assessment.weightBearing) ==
      WeightBearing.full;
  final normalWalking = latestWalking == WalkingQuality.normal;
  final noMechanicalSymptoms = !assessment.hasMechanicalSymptoms;
  if (latestPain >= 5) {
    blockers.add(
      'Pain is elevated, so protection and symptom control remain priorities.',
    );
  }
  if (latestSwelling.severity >= Swelling.moderate.severity) {
    blockers.add(
      'Moderate or severe swelling should calm before loading increases.',
    );
  }
  if (!hasFullExtension) {
    blockers.add('Full knee straightening is not yet restored.');
  }
  if (!hasFunctionalFlexion) {
    blockers.add('Knee bending is not yet functional.');
  }
  if (!fullWeightBearing) {
    blockers.add('Full weight bearing has not been reached.');
  }
  if (!latestWalking.isFunctional) {
    blockers.add('Walking quality still suggests protection is needed.');
  }
  final hasPhaseOneCriteria =
      hasFullExtension &&
      (!readinessKnown ||
          protocol.strongQuadSet && protocol.straightLegRaiseNoLag);
  final hasAdvancedStrength =
      !readinessKnown ||
      latestQuadSymmetry >= 80 &&
          latestHamstringSymmetry >= 80 &&
          latestHipSymmetry >= 80 &&
          latestBalanceSymmetry >= 80;
  final hasNeuromuscularCriteria =
      !readinessKnown ||
      controlledSingleLegSquat &&
          goodLandingControl &&
          painFreeLoading &&
          hasAdvancedStrength;
  final hasRunningReadiness =
      !readinessKnown ||
      ptClearedForRunning &&
          painFreeLoading &&
          fullRom &&
          latestQuadSymmetry >= 80 &&
          latestHamstringSymmetry >= 80 &&
          painFreeRepeatedHops;
  final hasReturnMetrics =
      latestQuadSymmetry >= 90 &&
      latestHamstringSymmetry >= 90 &&
      latestHipSymmetry >= 90 &&
      latestBalanceSymmetry >= 90 &&
      latestHopSymmetry >= 90 &&
      latestKoosSportsScore >= 90 &&
      latestIkdcScore >= 93 &&
      latestAclRsiScore >= 90 &&
      physicianClearedForSport &&
      completedJogRunProgram;
  final runningRestriction = assessment.hasRestriction('No Running');
  final highDemandRestriction =
      assessment.hasRestriction('No Deep Squats') ||
      assessment.hasRestriction('No Open Chain Extension');

  if (assessment.weeksPostOp < 4 ||
      blockers.isNotEmpty ||
      safetyFlags.isNotEmpty) {
    return PhaseEvaluation(
      phase: RehabPhase.protectionAndMotion,
      progress: 0.12,
      goals: const [
        'Calm pain and swelling.',
        'Restore full extension and comfortable flexion.',
        'Build confidence with safe walking.',
      ],
      blockers: [
        ...blockers,
        if (!hasFullExtension)
          'Protocol criteria require full knee extension before progressing.',
      ],
      safetyFlags: safetyFlags,
    );
  }

  if (!quietKnee ||
      !fullRom ||
      !fullWeightBearing ||
      !latestWalking.isFunctional ||
      readinessKnown && assessment.weeksPostOp < 8 && !hasPhaseOneCriteria ||
      readinessKnown && !painFreeLoading ||
      assessment.weeksPostOp < 8) {
    return PhaseEvaluation(
      phase: RehabPhase.earlyStrengthening,
      progress: 0.34,
      goals: const [
        'Build controlled closed-chain strength.',
        'Keep swelling quiet after sessions.',
        'Improve gait quality and daily tolerance.',
      ],
      blockers: [
        if (!quietKnee) 'Pain or swelling is still limiting progression.',
        if (!fullRom) 'Full functional range of motion is not yet confirmed.',
        if (!fullWeightBearing)
          'Full weight bearing is required before harder loading.',
        if (readinessKnown && !painFreeLoading)
          'Protocol criteria require no pain or swelling increase after exercise.',
        if (readinessKnown &&
            assessment.weeksPostOp < 8 &&
            !protocol.strongQuadSet)
          'A strong quad set with visible patellar glide is not confirmed.',
        if (readinessKnown &&
            assessment.weeksPostOp < 8 &&
            !protocol.straightLegRaiseNoLag)
          'Straight leg raise without lag is not confirmed.',
        if (!latestWalking.isFunctional)
          'Walking should be comfortable and controlled.',
      ],
      safetyFlags: const [],
    );
  }

  if (!normalWalking ||
      highDemandRestriction ||
      assessment.weeksPostOp < 12 ||
      readinessKnown && (!hasNeuromuscularCriteria || !hasAdvancedStrength)) {
    return PhaseEvaluation(
      phase: RehabPhase.advancedStrength,
      progress: 0.56,
      goals: const [
        'Develop single-leg strength and control.',
        'Introduce balance and proprioception criteria.',
        'Prepare for running readiness when cleared.',
      ],
      blockers: [
        if (!normalWalking)
          'Normal walking is needed before higher-demand drills.',
        if (highDemandRestriction)
          'Current restrictions limit advanced strengthening choices.',
        if (assessment.weeksPostOp < 12)
          'Early tissue healing still limits advanced work.',
        if (readinessKnown && !controlledSingleLegSquat)
          '10 controlled single-leg squats to about 60 degrees are not confirmed.',
        if (readinessKnown && !goodLandingControl)
          'Landing control on a drop-jump style task is not confirmed.',
        if (readinessKnown && !painFreeLoading)
          'Loading activities should be pain-free before neuromuscular progression.',
        if (readinessKnown && !hasAdvancedStrength)
          'Quad, hamstring, and hip/balance symmetry should reach at least 80%.',
      ],
      safetyFlags: const [],
    );
  }

  if (runningRestriction ||
      assessment.weeksPostOp < 20 ||
      readinessKnown && !hasRunningReadiness ||
      milestone?.canRun == false) {
    return PhaseEvaluation(
      phase: RehabPhase.neuromuscularControl,
      progress: 0.72,
      goals: const [
        'Refine balance, landing mechanics, and deceleration.',
        'Build readiness for running and change of direction.',
        'Track strength, hop, and balance symmetry.',
      ],
      blockers: [
        if (runningRestriction) 'Running is still listed as restricted.',
        if (assessment.weeksPostOp < 20)
          'Later-stage drills still need time plus criteria.',
        if (readinessKnown && !ptClearedForRunning)
          'PT clearance for running is not recorded.',
        if (readinessKnown && !painFreeRepeatedHops)
          'Pain-free repeated single-leg hopping is not confirmed.',
        if (readinessKnown && latestQuadSymmetry < 80)
          'Quad strength symmetry should be at least 80% before running progression.',
        if (milestone?.canRun == false)
          'Running tolerance has not been confirmed.',
      ],
      safetyFlags: const [],
    );
  }

  if (assessment.weeksPostOp >= 24 &&
      quietKnee &&
      fullRom &&
      normalWalking &&
      noMechanicalSymptoms &&
      (!readinessKnown || completedJogRunProgram) &&
      hasReturnMetrics) {
    return PhaseEvaluation(
      phase: RehabPhase.returnToSport,
      progress: 0.92,
      goals: const [
        'Progress sport-specific change of direction.',
        'Maintain strength and hop symmetry above 90%.',
        'Use PT clearance for high-risk drills and return decisions.',
      ],
      blockers: const [],
      safetyFlags: const [],
    );
  }

  return PhaseEvaluation(
    phase: RehabPhase.neuromuscularControl,
    progress: 0.78,
    goals: const [
      'Close remaining strength and hop symmetry gaps.',
      'Keep symptoms quiet after higher-demand sessions.',
      'Confirm PT clearance before unrestricted sport work.',
    ],
    blockers: [
      if (assessment.weeksPostOp < 24)
        'Return-to-sport work usually needs at least 24 weeks plus criteria.',
      if (!hasReturnMetrics)
        'Return metrics should reach 90% symmetry, KOOS-Sports 90+, IKDC 93+, ACL-RSI 90+, and clinician clearance.',
      if (readinessKnown && !completedJogRunProgram)
        'A jog/run progression without pain or swelling is not confirmed.',
      if (!quietKnee) 'Pain and swelling should be quiet.',
    ],
    safetyFlags: const [],
  );
}
