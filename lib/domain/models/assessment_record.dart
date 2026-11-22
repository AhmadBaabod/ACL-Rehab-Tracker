import 'package:acl_rehab/domain/models/assessment.dart';

enum AssessmentKind { initial, reassessment, retake }

extension AssessmentKindX on AssessmentKind {
  String get label {
    switch (this) {
      case AssessmentKind.initial:
        return 'Initial assessment';
      case AssessmentKind.reassessment:
        return 'Reassessment';
      case AssessmentKind.retake:
        return 'Corrected assessment';
    }
  }
}

/// A saved assessment revision. The history drives comparisons between
/// tests and the adaptive Assessment -> Plan -> Progress -> Retest cycle.
class AssessmentRecord {
  const AssessmentRecord({
    required this.id,
    required this.createdAt,
    required this.kind,
    required this.assessment,
    required this.phase,
  });

  final String id;
  final DateTime createdAt;
  final AssessmentKind kind;
  final Assessment assessment;

  /// Phase assigned when the assessment was saved.
  final RehabPhase phase;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'createdAt': createdAt.toIso8601String(),
      'kind': kind.name,
      'assessment': assessment.toJson(),
      'phase': phase.name,
    };
  }

  factory AssessmentRecord.fromJson(Map<String, dynamic> data) {
    final createdAt =
        DateTime.tryParse(data['createdAt'] as String? ?? '') ?? DateTime.now();
    return AssessmentRecord(
      id: data['id'] as String? ?? createdAt.microsecondsSinceEpoch.toString(),
      createdAt: createdAt,
      kind: AssessmentKind.values.firstWhere(
        (item) => item.name == data['kind'],
        orElse: () => AssessmentKind.initial,
      ),
      assessment: Assessment.fromJson(
        Map<String, dynamic>.from(data['assessment'] as Map? ?? const {}),
      ),
      phase: RehabPhase.values.firstWhere(
        (item) => item.name == data['phase'],
        orElse: () => RehabPhase.protectionAndMotion,
      ),
    );
  }
}
