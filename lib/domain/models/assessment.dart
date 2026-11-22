import 'dart:convert';

import 'package:acl_rehab/domain/models/training_profile.dart';

enum GraftType { patellarTendon, hamstring, quadriceps, allograft }

enum Swelling { none, mild, moderate, severe }

enum WeightBearing { partial, full, limited }

enum WalkingQuality { normal, slightLimp, painful, antalgic }

enum RehabPhase {
  protectionAndMotion,
  earlyStrengthening,
  advancedStrength,
  neuromuscularControl,
  returnToSport,
}

extension GraftTypeX on GraftType {
  String get label {
    switch (this) {
      case GraftType.patellarTendon:
        return 'Patellar Tendon (BTB)';
      case GraftType.hamstring:
        return 'Hamstring Tendon';
      case GraftType.quadriceps:
        return 'Quadriceps Tendon';
      case GraftType.allograft:
        return 'Allograft';
    }
  }

  String get educationTitle {
    switch (this) {
      case GraftType.patellarTendon:
        return 'Patellar tendon considerations';
      case GraftType.hamstring:
        return 'Hamstring graft considerations';
      case GraftType.quadriceps:
        return 'Quadriceps tendon considerations';
      case GraftType.allograft:
        return 'Allograft considerations';
    }
  }

  List<String> get educationPoints {
    switch (this) {
      case GraftType.patellarTendon:
        return const [
          'Kneeling discomfort can persist early on.',
          'Anterior knee pain should guide loading choices.',
          'Quadriceps strength should progress without symptom flare.',
        ];
      case GraftType.hamstring:
        return const [
          'Early hamstring loading often progresses more slowly.',
          'Use caution with resisted curls in early strengthening.',
          'Delay aggressive change-of-direction drills until criteria are met.',
        ];
      case GraftType.quadriceps:
        return const [
          'Quadriceps tendon sensitivity can affect kneeling and loading.',
          'Respect soreness around resisted knee extension work.',
          'Restore quad activation before advanced impact work.',
        ];
      case GraftType.allograft:
        return const [
          'Progression is often more conservative.',
          'Do not use calendar time alone for return-to-sport decisions.',
          'Clinical clearance is especially important before high-impact work.',
        ];
    }
  }

  String get education =>
      '$educationTitle\n${educationPoints.map((item) => '- $item').join('\n')}';
}

extension SwellingX on Swelling {
  String get label {
    switch (this) {
      case Swelling.none:
        return 'None';
      case Swelling.mild:
        return 'Mild';
      case Swelling.moderate:
        return 'Moderate';
      case Swelling.severe:
        return 'Severe';
    }
  }

  int get severity {
    switch (this) {
      case Swelling.none:
        return 0;
      case Swelling.mild:
        return 1;
      case Swelling.moderate:
        return 2;
      case Swelling.severe:
        return 3;
    }
  }
}

extension WeightBearingX on WeightBearing {
  String get label {
    switch (this) {
      case WeightBearing.partial:
        return 'Partial';
      case WeightBearing.full:
        return 'Full';
      case WeightBearing.limited:
        return 'Limited';
    }
  }
}

extension WalkingQualityX on WalkingQuality {
  String get label {
    switch (this) {
      case WalkingQuality.normal:
        return 'Normal';
      case WalkingQuality.slightLimp:
        return 'Slight limp';
      case WalkingQuality.painful:
        return 'Painful';
      case WalkingQuality.antalgic:
        return 'Antalgic';
    }
  }

  bool get isFunctional =>
      this == WalkingQuality.normal || this == WalkingQuality.slightLimp;
}

extension RehabPhaseX on RehabPhase {
  String get label {
    switch (this) {
      case RehabPhase.protectionAndMotion:
        return 'Protection & Motion';
      case RehabPhase.earlyStrengthening:
        return 'Early Strengthening';
      case RehabPhase.advancedStrength:
        return 'Advanced Strength';
      case RehabPhase.neuromuscularControl:
        return 'Neuromuscular Control';
      case RehabPhase.returnToSport:
        return 'Return to Sport';
    }
  }

  String get shortLabel {
    switch (this) {
      case RehabPhase.protectionAndMotion:
        return 'Phase 1';
      case RehabPhase.earlyStrengthening:
        return 'Phase 2';
      case RehabPhase.advancedStrength:
        return 'Phase 3A';
      case RehabPhase.neuromuscularControl:
        return 'Phase 3B';
      case RehabPhase.returnToSport:
        return 'Phase 4';
    }
  }

  int get order {
    switch (this) {
      case RehabPhase.protectionAndMotion:
        return 0;
      case RehabPhase.earlyStrengthening:
        return 1;
      case RehabPhase.advancedStrength:
        return 2;
      case RehabPhase.neuromuscularControl:
        return 3;
      case RehabPhase.returnToSport:
        return 4;
    }
  }
}

class Assessment {
  const Assessment({
    required this.surgeryDate,
    required this.graftType,
    required this.pain,
    required this.swelling,
    required this.canStraighten,
    required this.canBend,
    required this.weightBearing,
    required this.walkingQuality,
    required this.instability,
    required this.locking,
    required this.givingWay,
    required this.restrictions,
    required this.notes,
    this.protocolReadiness = const ProtocolReadiness(),
    this.confidence = 5,
    this.profile = const TrainingProfile(),
  });

  final DateTime surgeryDate;
  final GraftType graftType;
  final int pain;
  final Swelling swelling;
  final bool canStraighten;
  final bool canBend;
  final WeightBearing weightBearing;
  final WalkingQuality walkingQuality;
  final bool instability;
  final bool locking;
  final bool givingWay;
  final List<String> restrictions;
  final String notes;
  final ProtocolReadiness protocolReadiness;

  /// Self-rated confidence in the knee, 0 (none) to 10 (full).
  final int confidence;

  /// Goals, schedule, and equipment used to personalize the plan.
  final TrainingProfile profile;

  int get weeksPostOp {
    final now = DateTime.now();
    final difference = now.difference(surgeryDate).inDays;
    return difference <= 0 ? 0 : (difference / 7).floor();
  }

  bool get hasFullRom => canStraighten && canBend;

  bool get hasMechanicalSymptoms => instability || locking || givingWay;

  bool get hasFullWeightBearing => weightBearing == WeightBearing.full;

  bool get hasQuietKnee => pain <= 2 && swelling == Swelling.none;

  bool get hasProtocolQuietKnee =>
      hasQuietKnee && protocolReadiness.noPainOrSwellingAfterExercise;

  bool get hasClinicalRestrictions =>
      restrictions.isNotEmpty || notes.trim().isNotEmpty;

  bool hasRestriction(String value) =>
      restrictions.any((item) => item.toLowerCase() == value.toLowerCase());

  Assessment copyWith({
    DateTime? surgeryDate,
    GraftType? graftType,
    int? pain,
    Swelling? swelling,
    bool? canStraighten,
    bool? canBend,
    WeightBearing? weightBearing,
    WalkingQuality? walkingQuality,
    bool? instability,
    bool? locking,
    bool? givingWay,
    List<String>? restrictions,
    String? notes,
    ProtocolReadiness? protocolReadiness,
    int? confidence,
    TrainingProfile? profile,
  }) {
    return Assessment(
      surgeryDate: surgeryDate ?? this.surgeryDate,
      graftType: graftType ?? this.graftType,
      pain: pain ?? this.pain,
      swelling: swelling ?? this.swelling,
      canStraighten: canStraighten ?? this.canStraighten,
      canBend: canBend ?? this.canBend,
      weightBearing: weightBearing ?? this.weightBearing,
      walkingQuality: walkingQuality ?? this.walkingQuality,
      instability: instability ?? this.instability,
      locking: locking ?? this.locking,
      givingWay: givingWay ?? this.givingWay,
      restrictions: restrictions ?? this.restrictions,
      notes: notes ?? this.notes,
      protocolReadiness: protocolReadiness ?? this.protocolReadiness,
      confidence: confidence ?? this.confidence,
      profile: profile ?? this.profile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'surgeryDate': surgeryDate.toIso8601String(),
      'graftType': graftType.name,
      'pain': pain,
      'swelling': swelling.name,
      'canStraighten': canStraighten,
      'canBend': canBend,
      'weightBearing': weightBearing.name,
      'walkingQuality': walkingQuality.name,
      'instability': instability,
      'locking': locking,
      'givingWay': givingWay,
      'restrictions': restrictions,
      'notes': notes,
      'protocolReadiness': protocolReadiness.toJson(),
      'confidence': confidence,
      'profile': profile.toJson(),
    };
  }

  factory Assessment.fromJson(Map<String, dynamic> data) {
    return Assessment(
      surgeryDate:
          DateTime.tryParse(data['surgeryDate'] as String? ?? '') ??
          DateTime.now(),
      graftType: GraftType.values.firstWhere(
        (item) => item.name == data['graftType'],
        orElse: () => GraftType.hamstring,
      ),
      pain: data['pain'] as int? ?? 0,
      swelling: Swelling.values.firstWhere(
        (item) => item.name == data['swelling'],
        orElse: () => Swelling.none,
      ),
      canStraighten: data['canStraighten'] as bool? ?? false,
      canBend: data['canBend'] as bool? ?? false,
      weightBearing: WeightBearing.values.firstWhere(
        (item) => item.name == data['weightBearing'],
        orElse: () => WeightBearing.partial,
      ),
      walkingQuality: WalkingQuality.values.firstWhere(
        (item) => item.name == data['walkingQuality'],
        orElse: () => WalkingQuality.slightLimp,
      ),
      instability: data['instability'] as bool? ?? false,
      locking: data['locking'] as bool? ?? false,
      givingWay: data['givingWay'] as bool? ?? false,
      restrictions: List<String>.from(
        data['restrictions'] as List<dynamic>? ?? const [],
      ),
      notes: data['notes'] as String? ?? '',
      protocolReadiness: ProtocolReadiness.fromJson(
        Map<String, dynamic>.from(
          data['protocolReadiness'] as Map<dynamic, dynamic>? ?? const {},
        ),
      ),
      confidence: data['confidence'] as int? ?? 5,
      profile: data['profile'] == null
          ? TrainingProfile.legacyDefault()
          : TrainingProfile.fromJson(
              Map<String, dynamic>.from(data['profile'] as Map),
            ),
    );
  }

  String get json => jsonEncode(toJson());
}

class ProtocolReadiness {
  const ProtocolReadiness({
    this.readinessCompleted = false,
    this.straightLegRaiseNoLag = false,
    this.strongQuadSet = false,
    this.noPainOrSwellingAfterExercise = false,
    this.flexionNearOtherSide = false,
    this.singleLegSquatTenReps = false,
    this.dropJumpGoodControl = false,
    this.completedJogRunProgram = false,
    this.painFreeLoadingActivities = false,
    this.painFreeRepeatedSingleLegHops = false,
    this.quadStrengthSymmetry = 0,
    this.hamstringStrengthSymmetry = 0,
    this.gluteStrengthSymmetry = 0,
    this.balanceSymmetry = 0,
    this.hopTestSymmetry = 0,
    this.koosSportsScore = 0,
    this.ikdcScore = 0,
    this.aclRsiScore = 0,
    this.ptClearedForRunning = false,
    this.mdClearedForSport = false,
  });

  final bool readinessCompleted;
  final bool straightLegRaiseNoLag;
  final bool strongQuadSet;
  final bool noPainOrSwellingAfterExercise;
  final bool flexionNearOtherSide;
  final bool singleLegSquatTenReps;
  final bool dropJumpGoodControl;
  final bool completedJogRunProgram;
  final bool painFreeLoadingActivities;
  final bool painFreeRepeatedSingleLegHops;
  final int quadStrengthSymmetry;
  final int hamstringStrengthSymmetry;
  final int gluteStrengthSymmetry;
  final int balanceSymmetry;
  final int hopTestSymmetry;
  final int koosSportsScore;
  final int ikdcScore;
  final int aclRsiScore;
  final bool ptClearedForRunning;
  final bool mdClearedForSport;

  bool get phaseOneCriteriaMet =>
      !readinessCompleted ||
      straightLegRaiseNoLag && strongQuadSet && noPainOrSwellingAfterExercise;

  bool get phaseTwoCriteriaMet =>
      !readinessCompleted ||
      noPainOrSwellingAfterExercise && flexionNearOtherSide;

  bool get phaseThreeCriteriaMet =>
      !readinessCompleted ||
      singleLegSquatTenReps &&
          dropJumpGoodControl &&
          quadStrengthSymmetry >= 80 &&
          hamstringStrengthSymmetry >= 80 &&
          gluteStrengthSymmetry >= 80 &&
          balanceSymmetry >= 80;

  bool get runningReadinessMet =>
      !readinessCompleted ||
      ptClearedForRunning &&
          noPainOrSwellingAfterExercise &&
          flexionNearOtherSide &&
          quadStrengthSymmetry >= 80 &&
          painFreeRepeatedSingleLegHops;

  bool get returnToSportReadinessMet =>
      readinessCompleted &&
      mdClearedForSport &&
      completedJogRunProgram &&
      noPainOrSwellingAfterExercise &&
      quadStrengthSymmetry >= 90 &&
      hamstringStrengthSymmetry >= 90 &&
      gluteStrengthSymmetry >= 90 &&
      balanceSymmetry >= 90 &&
      hopTestSymmetry >= 90 &&
      koosSportsScore >= 90 &&
      ikdcScore >= 93 &&
      aclRsiScore >= 90;

  Map<String, dynamic> toJson() {
    return {
      'readinessCompleted': readinessCompleted,
      'straightLegRaiseNoLag': straightLegRaiseNoLag,
      'strongQuadSet': strongQuadSet,
      'noPainOrSwellingAfterExercise': noPainOrSwellingAfterExercise,
      'flexionNearOtherSide': flexionNearOtherSide,
      'singleLegSquatTenReps': singleLegSquatTenReps,
      'dropJumpGoodControl': dropJumpGoodControl,
      'completedJogRunProgram': completedJogRunProgram,
      'painFreeLoadingActivities': painFreeLoadingActivities,
      'painFreeRepeatedSingleLegHops': painFreeRepeatedSingleLegHops,
      'quadStrengthSymmetry': quadStrengthSymmetry,
      'hamstringStrengthSymmetry': hamstringStrengthSymmetry,
      'gluteStrengthSymmetry': gluteStrengthSymmetry,
      'balanceSymmetry': balanceSymmetry,
      'hopTestSymmetry': hopTestSymmetry,
      'koosSportsScore': koosSportsScore,
      'ikdcScore': ikdcScore,
      'aclRsiScore': aclRsiScore,
      'ptClearedForRunning': ptClearedForRunning,
      'mdClearedForSport': mdClearedForSport,
    };
  }

  factory ProtocolReadiness.fromJson(Map<String, dynamic> data) {
    return ProtocolReadiness(
      readinessCompleted: data['readinessCompleted'] as bool? ?? false,
      straightLegRaiseNoLag: data['straightLegRaiseNoLag'] as bool? ?? false,
      strongQuadSet: data['strongQuadSet'] as bool? ?? false,
      noPainOrSwellingAfterExercise:
          data['noPainOrSwellingAfterExercise'] as bool? ?? false,
      flexionNearOtherSide: data['flexionNearOtherSide'] as bool? ?? false,
      singleLegSquatTenReps: data['singleLegSquatTenReps'] as bool? ?? false,
      dropJumpGoodControl: data['dropJumpGoodControl'] as bool? ?? false,
      completedJogRunProgram: data['completedJogRunProgram'] as bool? ?? false,
      painFreeLoadingActivities:
          data['painFreeLoadingActivities'] as bool? ?? false,
      painFreeRepeatedSingleLegHops:
          data['painFreeRepeatedSingleLegHops'] as bool? ?? false,
      quadStrengthSymmetry: data['quadStrengthSymmetry'] as int? ?? 0,
      hamstringStrengthSymmetry: data['hamstringStrengthSymmetry'] as int? ?? 0,
      gluteStrengthSymmetry: data['gluteStrengthSymmetry'] as int? ?? 0,
      balanceSymmetry: data['balanceSymmetry'] as int? ?? 0,
      hopTestSymmetry: data['hopTestSymmetry'] as int? ?? 0,
      koosSportsScore: data['koosSportsScore'] as int? ?? 0,
      ikdcScore: data['ikdcScore'] as int? ?? 0,
      aclRsiScore: data['aclRsiScore'] as int? ?? 0,
      ptClearedForRunning: data['ptClearedForRunning'] as bool? ?? false,
      mdClearedForSport: data['mdClearedForSport'] as bool? ?? false,
    );
  }
}
