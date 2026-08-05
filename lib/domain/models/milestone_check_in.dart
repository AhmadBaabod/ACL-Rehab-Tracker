import 'package:acl_rehab/domain/models/assessment.dart';

class MilestoneCheckIn {
  const MilestoneCheckIn({
    required this.id,
    required this.createdAt,
    required this.pain,
    required this.swelling,
    required this.walkingQuality,
    required this.canRun,
    this.weightBearing,
    required this.hasFullExtension,
    required this.hasFunctionalFlexion,
    required this.confidence,
    required this.quadStrengthSymmetry,
    required this.hopTestSymmetry,
    required this.balanceSymmetry,
    required this.ptClearanceForSport,
    this.hamstringStrengthSymmetry,
    this.hipStrengthSymmetry,
    this.koosSportsScore,
    this.ikdcScore,
    this.aclRsiScore,
    this.painFreeLoadingActivities,
    this.painFreeRepeatedSingleLegHops,
    this.canPerformControlledSingleLegSquat,
    this.goodLandingControl,
    this.completedJogRunProgram,
    this.ptClearanceForRunning,
    this.physicianClearanceForSport,
    this.notes = '',
  });

  final String id;
  final DateTime createdAt;
  final int pain;
  final Swelling swelling;
  final WalkingQuality walkingQuality;
  final bool canRun;
  final WeightBearing? weightBearing;
  final bool hasFullExtension;
  final bool hasFunctionalFlexion;
  final int confidence;
  final int quadStrengthSymmetry;
  final int hopTestSymmetry;
  final int balanceSymmetry;
  final bool ptClearanceForSport;
  final int? hamstringStrengthSymmetry;
  final int? hipStrengthSymmetry;
  final int? koosSportsScore;
  final int? ikdcScore;
  final int? aclRsiScore;
  final bool? painFreeLoadingActivities;
  final bool? painFreeRepeatedSingleLegHops;
  final bool? canPerformControlledSingleLegSquat;
  final bool? goodLandingControl;
  final bool? completedJogRunProgram;
  final bool? ptClearanceForRunning;
  final bool? physicianClearanceForSport;
  final String notes;

  bool get hasQuietKnee => pain <= 2 && swelling == Swelling.none;

  bool get hasFunctionalRom => hasFullExtension && hasFunctionalFlexion;

  bool get hasAdvancedStrength =>
      quadStrengthSymmetry >= 80 && balanceSymmetry >= 80;

  bool get hasSessionReadinessData =>
      hamstringStrengthSymmetry != null ||
      hipStrengthSymmetry != null ||
      painFreeLoadingActivities != null ||
      painFreeRepeatedSingleLegHops != null ||
      canPerformControlledSingleLegSquat != null ||
      goodLandingControl != null ||
      completedJogRunProgram != null ||
      ptClearanceForRunning != null ||
      physicianClearanceForSport != null;

  bool get hasReturnToSportMetrics {
    return quadStrengthSymmetry >= 90 &&
        hopTestSymmetry >= 90 &&
        balanceSymmetry >= 90 &&
        confidence >= 7 &&
        ptClearanceForSport;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'pain': pain,
      'swelling': swelling.name,
      'walkingQuality': walkingQuality.name,
      'canRun': canRun,
      'weightBearing': weightBearing?.name,
      'hasFullExtension': hasFullExtension,
      'hasFunctionalFlexion': hasFunctionalFlexion,
      'confidence': confidence,
      'quadStrengthSymmetry': quadStrengthSymmetry,
      'hopTestSymmetry': hopTestSymmetry,
      'balanceSymmetry': balanceSymmetry,
      'ptClearanceForSport': ptClearanceForSport,
      'hamstringStrengthSymmetry': hamstringStrengthSymmetry,
      'hipStrengthSymmetry': hipStrengthSymmetry,
      'koosSportsScore': koosSportsScore,
      'ikdcScore': ikdcScore,
      'aclRsiScore': aclRsiScore,
      'painFreeLoadingActivities': painFreeLoadingActivities,
      'painFreeRepeatedSingleLegHops': painFreeRepeatedSingleLegHops,
      'canPerformControlledSingleLegSquat': canPerformControlledSingleLegSquat,
      'goodLandingControl': goodLandingControl,
      'completedJogRunProgram': completedJogRunProgram,
      'ptClearanceForRunning': ptClearanceForRunning,
      'physicianClearanceForSport': physicianClearanceForSport,
      'notes': notes,
    };
  }

  factory MilestoneCheckIn.fromJson(Map<String, dynamic> data) {
    return MilestoneCheckIn(
      id:
          data['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      pain: data['pain'] as int? ?? 0,
      swelling: Swelling.values.firstWhere(
        (item) => item.name == data['swelling'],
        orElse: () => Swelling.none,
      ),
      walkingQuality: WalkingQuality.values.firstWhere(
        (item) => item.name == data['walkingQuality'],
        orElse: () => WalkingQuality.normal,
      ),
      canRun: data['canRun'] as bool? ?? false,
      weightBearing: _weightBearingFromName(data['weightBearing']),
      hasFullExtension: data['hasFullExtension'] as bool? ?? false,
      hasFunctionalFlexion: data['hasFunctionalFlexion'] as bool? ?? false,
      confidence: data['confidence'] as int? ?? 0,
      quadStrengthSymmetry: data['quadStrengthSymmetry'] as int? ?? 0,
      hopTestSymmetry: data['hopTestSymmetry'] as int? ?? 0,
      balanceSymmetry: data['balanceSymmetry'] as int? ?? 0,
      ptClearanceForSport: data['ptClearanceForSport'] as bool? ?? false,
      hamstringStrengthSymmetry: data['hamstringStrengthSymmetry'] as int?,
      hipStrengthSymmetry: data['hipStrengthSymmetry'] as int?,
      koosSportsScore: data['koosSportsScore'] as int?,
      ikdcScore: data['ikdcScore'] as int?,
      aclRsiScore: data['aclRsiScore'] as int?,
      painFreeLoadingActivities: data['painFreeLoadingActivities'] as bool?,
      painFreeRepeatedSingleLegHops:
          data['painFreeRepeatedSingleLegHops'] as bool?,
      canPerformControlledSingleLegSquat:
          data['canPerformControlledSingleLegSquat'] as bool?,
      goodLandingControl: data['goodLandingControl'] as bool?,
      completedJogRunProgram: data['completedJogRunProgram'] as bool?,
      ptClearanceForRunning: data['ptClearanceForRunning'] as bool?,
      physicianClearanceForSport: data['physicianClearanceForSport'] as bool?,
      notes: data['notes'] as String? ?? '',
    );
  }

  static WeightBearing? _weightBearingFromName(Object? value) {
    for (final item in WeightBearing.values) {
      if (item.name == value) return item;
    }
    return null;
  }
}
