import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/milestone_check_in.dart';

enum ExerciseCategory {
  mobility,
  strength,
  balanceProprioception,
  neuromuscularControl,
  changeOfDirection,
  returnToSport,
}

enum DifficultyLevel { foundation, moderate, advanced, sport }

enum SessionBlock {
  mobility,
  bilateralStrength,
  unilateralStrength,
  posteriorChain,
  balanceControl,
  landingPlyometric,
  runningAgility,
  sportSpecific,
}

extension ExerciseCategoryX on ExerciseCategory {
  String get label {
    switch (this) {
      case ExerciseCategory.mobility:
        return 'Mobility';
      case ExerciseCategory.strength:
        return 'Strength';
      case ExerciseCategory.balanceProprioception:
        return 'Balance & Proprioception';
      case ExerciseCategory.neuromuscularControl:
        return 'Neuromuscular Control';
      case ExerciseCategory.changeOfDirection:
        return 'Change of Direction';
      case ExerciseCategory.returnToSport:
        return 'Return to Sport';
    }
  }
}

extension DifficultyLevelX on DifficultyLevel {
  String get label {
    switch (this) {
      case DifficultyLevel.foundation:
        return 'Foundation';
      case DifficultyLevel.moderate:
        return 'Moderate';
      case DifficultyLevel.advanced:
        return 'Advanced';
      case DifficultyLevel.sport:
        return 'Sport';
    }
  }
}

extension SessionBlockX on SessionBlock {
  String get label {
    switch (this) {
      case SessionBlock.mobility:
        return 'Mobility';
      case SessionBlock.bilateralStrength:
        return 'Primary strength';
      case SessionBlock.unilateralStrength:
        return 'Single-leg strength';
      case SessionBlock.posteriorChain:
        return 'Posterior chain';
      case SessionBlock.balanceControl:
        return 'Balance & control';
      case SessionBlock.landingPlyometric:
        return 'Landing & plyometrics';
      case SessionBlock.runningAgility:
        return 'Running & agility';
      case SessionBlock.sportSpecific:
        return 'Sport-specific';
    }
  }
}

class ExerciseCriteria {
  const ExerciseCriteria({
    this.minimumWeeks = 0,
    this.maximumPain = 10,
    this.allowedSwelling = Swelling.severe,
    this.requiresFullExtension = false,
    this.requiresFunctionalFlexion = false,
    this.requiresFullWeightBearing = false,
    this.requiresNormalWalking = false,
    this.requiresNoMechanicalSymptoms = true,
    this.minimumQuadSymmetry = 0,
    this.minimumHamstringSymmetry = 0,
    this.minimumHipSymmetry = 0,
    this.minimumHopSymmetry = 0,
    this.minimumBalanceSymmetry = 0,
    this.requiresPainFreeLoadingActivities = false,
    this.requiresPainFreeRepeatedSingleLegHops = false,
    this.requiresGoodLandingControl = false,
    this.requiresCompletedJogRunProgram = false,
    this.requiresRunningTolerance = false,
    this.requiresPtClearance = false,
    this.requiresPhysicianClearance = false,
    this.minimumWeeksForHamstringGraft,
    this.minimumWeeksForAllograft,
    this.blockingRestrictions = const [],
  });

  final int minimumWeeks;
  final int maximumPain;
  final Swelling allowedSwelling;
  final bool requiresFullExtension;
  final bool requiresFunctionalFlexion;
  final bool requiresFullWeightBearing;
  final bool requiresNormalWalking;
  final bool requiresNoMechanicalSymptoms;
  final int minimumQuadSymmetry;
  final int minimumHamstringSymmetry;
  final int minimumHipSymmetry;
  final int minimumHopSymmetry;
  final int minimumBalanceSymmetry;
  final bool requiresPainFreeLoadingActivities;
  final bool requiresPainFreeRepeatedSingleLegHops;
  final bool requiresGoodLandingControl;
  final bool requiresCompletedJogRunProgram;
  final bool requiresRunningTolerance;
  final bool requiresPtClearance;
  final bool requiresPhysicianClearance;
  final int? minimumWeeksForHamstringGraft;
  final int? minimumWeeksForAllograft;
  final List<String> blockingRestrictions;

  List<String> unmetReasons(
    Assessment assessment,
    MilestoneCheckIn? milestone,
  ) {
    final reasons = <String>[];
    final protocol = assessment.protocolReadiness;
    final currentPain = milestone?.pain ?? assessment.pain;
    final currentSwelling = milestone?.swelling ?? assessment.swelling;
    final quadSymmetry =
        milestone?.quadStrengthSymmetry ?? protocol.quadStrengthSymmetry;
    final hamstringSymmetry =
        milestone?.hamstringStrengthSymmetry ??
        protocol.hamstringStrengthSymmetry;
    final hipSymmetry =
        milestone?.hipStrengthSymmetry ?? protocol.gluteStrengthSymmetry;
    final hopSymmetry = milestone?.hopTestSymmetry ?? protocol.hopTestSymmetry;
    final balanceSymmetry =
        milestone?.balanceSymmetry ?? protocol.balanceSymmetry;
    final canRun = milestone?.canRun ?? protocol.completedJogRunProgram;
    final painFreeLoading =
        milestone?.painFreeLoadingActivities ??
        protocol.painFreeLoadingActivities;
    final painFreeRepeatedHops =
        milestone?.painFreeRepeatedSingleLegHops ??
        protocol.painFreeRepeatedSingleLegHops;
    final goodLandingControl =
        milestone?.goodLandingControl ?? protocol.dropJumpGoodControl;
    final completedJogRunProgram =
        milestone?.completedJogRunProgram ?? protocol.completedJogRunProgram;
    final hasPtClearance =
        milestone?.ptClearanceForSport == true ||
        milestone?.ptClearanceForRunning == true ||
        protocol.ptClearedForRunning ||
        protocol.mdClearedForSport;
    final hasPhysicianClearance =
        milestone?.physicianClearanceForSport ?? protocol.mdClearedForSport;

    if (assessment.weeksPostOp < minimumWeeks) {
      reasons.add(
        'At least week $minimumWeeks is usually needed before this drill is considered.',
      );
    }
    if (assessment.graftType == GraftType.hamstring &&
        minimumWeeksForHamstringGraft != null &&
        assessment.weeksPostOp < minimumWeeksForHamstringGraft!) {
      reasons.add(
        'Hamstring graft precautions keep this loading below week '
        '$minimumWeeksForHamstringGraft.',
      );
    }
    if (assessment.graftType == GraftType.allograft &&
        minimumWeeksForAllograft != null &&
        assessment.weeksPostOp < minimumWeeksForAllograft!) {
      reasons.add(
        'Allograft precautions keep this drill below week '
        '$minimumWeeksForAllograft.',
      );
    }
    if (currentPain > maximumPain) {
      reasons.add('Pain should be $maximumPain/10 or lower.');
    }
    if (currentSwelling.severity > allowedSwelling.severity) {
      reasons.add(
        'Swelling should be ${allowedSwelling.label.toLowerCase()} or better.',
      );
    }
    if (requiresFullExtension &&
        !assessment.canStraighten &&
        milestone?.hasFullExtension != true) {
      reasons.add('Full knee straightening is required.');
    }
    if (requiresFunctionalFlexion &&
        !assessment.canBend &&
        milestone?.hasFunctionalFlexion != true) {
      reasons.add('Functional knee bending is required.');
    }
    if (requiresFullWeightBearing &&
        (milestone?.weightBearing ?? assessment.weightBearing) !=
            WeightBearing.full) {
      reasons.add('Full weight bearing is required.');
    }
    if (requiresNormalWalking) {
      final walking = milestone?.walkingQuality ?? assessment.walkingQuality;
      if (walking != WalkingQuality.normal) {
        reasons.add('Walking should be normal without a limp.');
      }
    }
    if (requiresNoMechanicalSymptoms && assessment.hasMechanicalSymptoms) {
      reasons.add(
        'Instability, locking, or giving way needs clinical review first.',
      );
    }
    if (minimumQuadSymmetry > 0 && quadSymmetry < minimumQuadSymmetry) {
      reasons.add(
        'Quad strength symmetry should be at least $minimumQuadSymmetry%.',
      );
    }
    if (minimumHamstringSymmetry > 0 &&
        hamstringSymmetry < minimumHamstringSymmetry) {
      reasons.add(
        'Hamstring strength symmetry should be at least $minimumHamstringSymmetry%.',
      );
    }
    if (minimumHipSymmetry > 0 && hipSymmetry < minimumHipSymmetry) {
      reasons.add(
        'Hip/glute strength symmetry should be at least $minimumHipSymmetry%.',
      );
    }
    if (minimumHopSymmetry > 0 && hopSymmetry < minimumHopSymmetry) {
      reasons.add('Hop test symmetry should be at least $minimumHopSymmetry%.');
    }
    if (minimumBalanceSymmetry > 0 &&
        balanceSymmetry < minimumBalanceSymmetry) {
      reasons.add(
        'Balance symmetry should be at least $minimumBalanceSymmetry%.',
      );
    }
    if (requiresPainFreeLoadingActivities && !painFreeLoading) {
      reasons.add('Loading activities should be pain-free.');
    }
    if (requiresPainFreeRepeatedSingleLegHops && !painFreeRepeatedHops) {
      reasons.add('Repeated single-leg hops should be pain-free.');
    }
    if (requiresGoodLandingControl && !goodLandingControl) {
      reasons.add('Landing mechanics should be controlled and symmetrical.');
    }
    if (requiresCompletedJogRunProgram && !completedJogRunProgram) {
      reasons.add(
        'A walk/jog or running progression should be completed without symptoms.',
      );
    }
    if (requiresRunningTolerance && !canRun) {
      reasons.add('Running tolerance should be confirmed first.');
    }
    if (requiresPtClearance && !hasPtClearance) {
      reasons.add('PT clearance is required before this exercise unlocks.');
    }
    if (requiresPhysicianClearance && !hasPhysicianClearance) {
      reasons.add(
        'Physician clearance is required before this return-to-sport drill unlocks.',
      );
    }
    for (final restriction in blockingRestrictions) {
      if (assessment.hasRestriction(restriction)) {
        reasons.add('$restriction is currently listed as a restriction.');
      }
    }

    return reasons;
  }
}

class ExerciseUnlockStatus {
  const ExerciseUnlockStatus({required this.isUnlocked, required this.reasons});

  final bool isUnlocked;
  final List<String> reasons;
}

class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.targetMuscles,
    required this.equipment,
    required this.imagePlaceholder,
    required this.videoPlaceholder,
    required this.sets,
    required this.reps,
    required this.holdTime,
    required this.regression,
    required this.progression,
    required this.difficultyLevel,
    required this.criteriaRequired,
    required this.phase,
    required this.category,
    required this.sessionBlock,
    required this.medicalNotes,
    required this.safetyWarnings,
    this.alternativeExerciseIds = const [],
  });

  final String id;
  final String name;
  final String description;
  final List<String> instructions;
  final List<String> targetMuscles;
  final List<String> equipment;
  final String imagePlaceholder;
  final String videoPlaceholder;
  final int sets;
  final String reps;
  final String holdTime;
  final String regression;
  final String progression;
  final DifficultyLevel difficultyLevel;
  final ExerciseCriteria criteriaRequired;
  final RehabPhase phase;
  final ExerciseCategory category;
  final SessionBlock sessionBlock;
  final String medicalNotes;
  final List<String> safetyWarnings;
  final List<String> alternativeExerciseIds;

  ExerciseUnlockStatus unlockStatus(
    Assessment assessment,
    MilestoneCheckIn? milestone,
  ) {
    final reasons = criteriaRequired.unmetReasons(assessment, milestone);
    return ExerciseUnlockStatus(isUnlocked: reasons.isEmpty, reasons: reasons);
  }
}
