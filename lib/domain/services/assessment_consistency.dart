import 'package:acl_rehab/domain/models/assessment.dart';

/// An answer combination that is unusual or contradictory. The plan always
/// follows the more cautious interpretation, described in [resolution].
class ConsistencyIssue {
  const ConsistencyIssue({
    required this.id,
    required this.message,
    required this.resolution,
  });

  final String id;
  final String message;
  final String resolution;
}

List<ConsistencyIssue> checkAssessmentConsistency(Assessment assessment) {
  final issues = <ConsistencyIssue>[];
  final protocol = assessment.protocolReadiness;
  final weeks = assessment.weeksPostOp;

  if (assessment.walkingQuality == WalkingQuality.normal &&
      assessment.weightBearing != WeightBearing.full) {
    issues.add(
      ConsistencyIssue(
        id: 'walking-vs-weight-bearing',
        message:
            'Walking is marked normal, but weight bearing is '
            '${assessment.weightBearing.label.toLowerCase()}.',
        resolution:
            'The plan follows the weight-bearing limit until full weight bearing is confirmed.',
      ),
    );
  }
  if (!assessment.canStraighten && protocol.straightLegRaiseNoLag) {
    issues.add(
      const ConsistencyIssue(
        id: 'slr-vs-extension',
        message:
            'A straight leg raise without lag usually needs full knee extension, '
            'but extension is marked limited.',
        resolution: 'Extension is treated as limited and stays a top priority.',
      ),
    );
  }
  if (protocol.noPainOrSwellingAfterExercise &&
      assessment.swelling.severity >= Swelling.moderate.severity) {
    issues.add(
      ConsistencyIssue(
        id: 'loading-vs-swelling',
        message:
            'No swelling after exercise is marked, but current swelling is '
            '${assessment.swelling.label.toLowerCase()}.',
        resolution: 'Loading is dosed for the current swelling level.',
      ),
    );
  }
  if (protocol.completedJogRunProgram && !protocol.ptClearedForRunning) {
    issues.add(
      const ConsistencyIssue(
        id: 'jog-without-clearance',
        message:
            'A walk/jog progression is marked complete without PT running clearance.',
        resolution:
            'Running drills stay locked until running clearance is recorded.',
      ),
    );
  }
  if (protocol.ptClearedForRunning && assessment.hasRestriction('No Running')) {
    issues.add(
      const ConsistencyIssue(
        id: 'clearance-vs-restriction',
        message:
            'Running clearance is recorded, but "No Running" is still listed as a restriction.',
        resolution:
            'The restriction wins. Remove it only when your team lifts it.',
      ),
    );
  }
  if (weeks < 12 &&
      (protocol.painFreeRepeatedSingleLegHops ||
          protocol.dropJumpGoodControl)) {
    issues.add(
      const ConsistencyIssue(
        id: 'early-impact-testing',
        message:
            'Hop or landing testing is rarely done before about 12 weeks after surgery.',
        resolution:
            'Impact drills stay locked by time and strength criteria regardless.',
      ),
    );
  }
  if (protocol.mdClearedForSport && weeks < 24) {
    issues.add(
      const ConsistencyIssue(
        id: 'early-sport-clearance',
        message:
            'Sport clearance before about 6 months is unusual. Please confirm it with your surgeon.',
        resolution:
            'Return-to-sport drills still require their time and strength criteria.',
      ),
    );
  }
  if (protocol.hopTestSymmetry >= 90 &&
      protocol.quadStrengthSymmetry > 0 &&
      protocol.quadStrengthSymmetry < 70) {
    issues.add(
      const ConsistencyIssue(
        id: 'hop-vs-quad',
        message:
            'Hop symmetry of 90%+ with quadriceps symmetry below 70% is an unusual combination.',
        resolution:
            'Quadriceps strength remains a focus; hop drills stay gated by strength criteria.',
      ),
    );
  }

  return issues;
}
