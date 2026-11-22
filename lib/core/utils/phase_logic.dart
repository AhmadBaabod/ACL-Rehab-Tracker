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
      'Your knee feels unstable or gives way. Tell your doctor or physio.',
    );
  }
  if (assessment.locking) {
    safetyFlags.add('Your knee locks. Tell your doctor or physio.');
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
    blockers.add('Pain is high, so we keep things gentle.');
  }
  if (latestSwelling.severity >= Swelling.moderate.severity) {
    blockers.add('Swelling needs to calm down first.');
  }
  if (!hasFullExtension) {
    blockers.add('Your knee does not fully straighten yet.');
  }
  if (!hasFunctionalFlexion) {
    blockers.add('Your knee does not bend enough yet.');
  }
  if (!fullWeightBearing) {
    blockers.add('You are not walking on your full weight yet.');
  }
  if (!latestWalking.isFunctional) {
    blockers.add('You still walk with a limp.');
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
        'Get the knee fully straight and bending well.',
        'Walk safely and with confidence.',
      ],
      blockers: [...blockers],
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
        'Build basic leg strength.',
        'Keep swelling low after workouts.',
        'Walk normally and handle daily tasks.',
      ],
      blockers: [
        if (!quietKnee) 'Pain or swelling is still holding you back.',
        if (!fullRom) 'Full knee movement is not confirmed yet.',
        if (!fullWeightBearing)
          'Walk on your full weight before harder exercises.',
        if (readinessKnown && !painFreeLoading)
          'Exercise should not increase pain or swelling.',
        if (readinessKnown &&
            assessment.weeksPostOp < 8 &&
            !protocol.strongQuadSet)
          'A strong thigh squeeze is not confirmed yet.',
        if (readinessKnown &&
            assessment.weeksPostOp < 8 &&
            !protocol.straightLegRaiseNoLag)
          'A straight leg raise without the knee bending is not confirmed yet.',
        if (!latestWalking.isFunctional) 'Walking should feel comfortable.',
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
        'Build strength on one leg.',
        'Improve your balance.',
        'Get ready for running.',
      ],
      blockers: [
        if (!normalWalking) 'Walk normally before harder exercises.',
        if (highDemandRestriction) 'Your restrictions limit harder exercises.',
        if (assessment.weeksPostOp < 12) 'Your graft is still healing.',
        if (readinessKnown && !controlledSingleLegSquat)
          '10 controlled one-leg squats are not confirmed yet.',
        if (readinessKnown && !goodLandingControl)
          'Good landing control is not confirmed yet.',
        if (readinessKnown && !painFreeLoading)
          'Exercises should be pain-free first.',
        if (readinessKnown && !hasAdvancedStrength)
          'Your operated leg should reach 80% of the other leg.',
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
        'Improve balance, landing, and stopping.',
        'Get ready for running and turning.',
        'Compare both legs in strength, hops, and balance.',
      ],
      blockers: [
        if (runningRestriction) 'Running is still restricted.',
        if (assessment.weeksPostOp < 20)
          'These drills need more time and progress.',
        if (readinessKnown && !ptClearedForRunning)
          'Your physio has not cleared you to run yet.',
        if (readinessKnown && !painFreeRepeatedHops)
          'Pain-free hopping on one leg is not confirmed yet.',
        if (readinessKnown && latestQuadSymmetry < 80)
          'Thigh strength should reach 80% of the other leg before running.',
        if (milestone?.canRun == false)
          'Running without pain is not confirmed yet.',
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
        'Practise turning and cutting for your sport.',
        'Keep both legs within 90% of each other.',
        'Get your physio to clear you for risky drills and sport.',
      ],
      blockers: const [],
      safetyFlags: const [],
    );
  }

  return PhaseEvaluation(
    phase: RehabPhase.neuromuscularControl,
    progress: 0.78,
    goals: const [
      'Close the last strength gaps between your legs.',
      'Keep pain and swelling low after hard workouts.',
      'Get your physio to clear you for full sport.',
    ],
    blockers: [
      if (assessment.weeksPostOp < 24) 'Sport usually needs at least 24 weeks.',
      if (!hasReturnMetrics)
        'You need 90% leg symmetry, good knee scores, and clearance from your physio.',
      if (readinessKnown && !completedJogRunProgram)
        'A pain-free running program is not confirmed yet.',
      if (!quietKnee) 'Pain and swelling should be low.',
    ],
    safetyFlags: const [],
  );
}
