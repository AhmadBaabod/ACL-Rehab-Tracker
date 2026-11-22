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
        resolution: 'The plan follows your weight-bearing limit for now.',
      ),
    );
  }
  if (!assessment.canStraighten && protocol.straightLegRaiseNoLag) {
    issues.add(
      const ConsistencyIssue(
        id: 'slr-vs-extension',
        message:
            'You can do a straight leg raise, but your knee does not fully straighten.',
        resolution: 'Straightening the knee stays a top priority.',
      ),
    );
  }
  if (protocol.noPainOrSwellingAfterExercise &&
      assessment.swelling.severity >= Swelling.moderate.severity) {
    issues.add(
      ConsistencyIssue(
        id: 'loading-vs-swelling',
        message:
            'You said exercise causes no swelling, but you have ${assessment.swelling.label.toLowerCase()} swelling now.',
        resolution: 'Exercises are set for your current swelling.',
      ),
    );
  }
  if (protocol.completedJogRunProgram && !protocol.ptClearedForRunning) {
    issues.add(
      const ConsistencyIssue(
        id: 'jog-without-clearance',
        message:
            'You finished walk/jog, but your physio has not cleared you to run.',
        resolution: 'Running stays locked until your physio clears it.',
      ),
    );
  }
  if (protocol.ptClearedForRunning && assessment.hasRestriction('No Running')) {
    issues.add(
      const ConsistencyIssue(
        id: 'clearance-vs-restriction',
        message:
            'You are cleared to run, but "No Running" is still a restriction.',
        resolution:
            'The restriction comes first. Remove it only when your physio says so.',
      ),
    );
  }
  if (weeks < 12 &&
      (protocol.painFreeRepeatedSingleLegHops ||
          protocol.dropJumpGoodControl)) {
    issues.add(
      const ConsistencyIssue(
        id: 'early-impact-testing',
        message: 'Hop tests are rarely done before 12 weeks.',
        resolution: 'Jumping drills stay locked until you are ready.',
      ),
    );
  }
  if (protocol.mdClearedForSport && weeks < 24) {
    issues.add(
      const ConsistencyIssue(
        id: 'early-sport-clearance',
        message:
            'Sport clearance before 6 months is unusual. Please check with your surgeon.',
        resolution: 'Sport drills still need enough time and strength.',
      ),
    );
  }
  if (protocol.hopTestSymmetry >= 90 &&
      protocol.quadStrengthSymmetry > 0 &&
      protocol.quadStrengthSymmetry < 70) {
    issues.add(
      const ConsistencyIssue(
        id: 'hop-vs-quad',
        message: 'Hops at 90% with thigh strength under 70% is unusual.',
        resolution:
            'Thigh strength stays a focus. Hop drills wait for strength.',
      ),
    );
  }

  return issues;
}
