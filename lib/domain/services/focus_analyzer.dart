import 'package:acl_rehab/domain/models/assessment.dart';
import 'package:acl_rehab/domain/models/rehab_plan.dart';
import 'package:acl_rehab/domain/models/training_profile.dart';
import 'package:acl_rehab/domain/services/rehab_status.dart';

/// Turns assessment answers into prioritized focus areas (weaknesses and
/// limitations) that the plan must address.
class FocusAnalyzer {
  const FocusAnalyzer._();

  static List<FocusArea> analyze(
    RehabStatus status,
    RehabPhase phase,
    TrainingProfile profile,
  ) {
    final areas = <FocusArea>[];
    final order = phase.order;
    final goal = profile.goal;

    void add(
      FocusAreaType type,
      FocusPriority priority,
      String title,
      String detail,
    ) {
      areas.add(
        FocusArea(type: type, priority: priority, title: title, detail: detail),
      );
    }

    if (status.mechanicalSymptoms) {
      add(
        FocusAreaType.mechanicalSymptoms,
        FocusPriority.high,
        'Knee instability or locking',
        'Tell your doctor or physio. Until then, the plan keeps to gentle movement.',
      );
    }
    if (!status.fullExtension) {
      add(
        FocusAreaType.extension,
        FocusPriority.high,
        'Straighten the knee fully',
        'Your knee does not fully straighten yet. This comes first.',
      );
    }
    if (!status.functionalFlexion) {
      add(
        FocusAreaType.flexion,
        status.weeksPostOp >= 6 ? FocusPriority.high : FocusPriority.medium,
        'Improve knee bending',
        status.readinessKnown
            ? 'Your knee does not bend as far as the other one yet.'
            : 'Your knee does not bend enough yet.',
      );
    }
    if (status.swelling != Swelling.none) {
      add(
        FocusAreaType.swelling,
        status.swelling.severity >= Swelling.moderate.severity
            ? FocusPriority.high
            : FocusPriority.medium,
        'Reduce swelling',
        '${status.swelling.label} swelling. Exercises stay light until it goes down.',
      );
    }
    if (status.pain >= 3) {
      add(
        FocusAreaType.pain,
        status.pain >= 5 ? FocusPriority.high : FocusPriority.medium,
        'Keep pain controlled',
        'Pain is ${status.pain}/10. Exercises are kept easy enough not to make it worse.',
      );
    }
    if (status.readinessKnown &&
        status.weeksPostOp < 16 &&
        (!status.straightLegRaiseNoLag || !status.strongQuadSet)) {
      final missing = [
        if (!status.straightLegRaiseNoLag)
          'a straight leg raise without the knee bending',
        if (!status.strongQuadSet) 'a strong thigh squeeze',
      ];
      add(
        FocusAreaType.quadActivation,
        order <= RehabPhase.earlyStrengthening.order
            ? FocusPriority.high
            : FocusPriority.medium,
        'Wake up the thigh muscle',
        'You have not yet confirmed ${missing.join(' or ')}.',
      );
    }
    if (!status.normalWalking || !status.fullWeightBearing) {
      add(
        FocusAreaType.gait,
        order == 0 ? FocusPriority.high : FocusPriority.medium,
        'Walk normally',
        'Walking: ${status.walking.label.toLowerCase()}, weight bearing: '
            '${status.weightBearing.label.toLowerCase()}.',
      );
    }

    if (order >= RehabPhase.earlyStrengthening.order) {
      final quad = status.quadSymmetry;
      if (quad == null) {
        add(
          FocusAreaType.quadStrength,
          FocusPriority.medium,
          'Build thigh strength',
          order >= RehabPhase.advancedStrength.order
              ? 'Ask your physio to test your thigh strength. It is the most common weakness after ACL surgery.'
              : 'Thigh weakness is the most common problem after ACL surgery.',
        );
      } else if (quad < 80) {
        add(
          FocusAreaType.quadStrength,
          FocusPriority.high,
          'Close the quadriceps gap',
          'Thigh strength is $quad% of the other leg. Aim for 80% now, 90% for sport.',
        );
      } else if (quad < 90 && order >= RehabPhase.neuromuscularControl.order) {
        add(
          FocusAreaType.quadStrength,
          FocusPriority.medium,
          'Close the quadriceps gap',
          'Thigh strength is $quad% of the other leg. Aim for 90% before sport.',
        );
      }
    }

    if (order >= RehabPhase.advancedStrength.order) {
      final hamstring = status.hamstringSymmetry;
      if (hamstring != null && hamstring < 80) {
        add(
          FocusAreaType.hamstringStrength,
          FocusPriority.high,
          'Build hamstring strength',
          'Hamstring strength is $hamstring% of the other leg. Aim for 80%, then 90%.',
        );
      } else if (hamstring != null &&
          hamstring < 90 &&
          order >= RehabPhase.neuromuscularControl.order) {
        add(
          FocusAreaType.hamstringStrength,
          FocusPriority.medium,
          'Build hamstring strength',
          'Hamstring strength is $hamstring% of the other leg. Aim for 90% before sport.',
        );
      } else if (hamstring == null && status.graftType == GraftType.hamstring) {
        add(
          FocusAreaType.hamstringStrength,
          FocusPriority.low,
          'Rebuild hamstring strength',
          'With a hamstring graft, this strength comes back slowly.',
        );
      }
    }

    if (order >= RehabPhase.earlyStrengthening.order) {
      final hip = status.hipSymmetry;
      if (hip != null && hip < 90) {
        add(
          FocusAreaType.hipStrength,
          hip < 70 ? FocusPriority.high : FocusPriority.medium,
          'Strengthen hip control',
          'Hip strength is $hip% of the other leg. Aim for 90%.',
        );
      }
      final balance = status.balanceSymmetry;
      if (balance != null && balance < 90) {
        add(
          FocusAreaType.balance,
          balance < 75 ? FocusPriority.high : FocusPriority.medium,
          'Improve single-leg balance',
          'Balance is $balance% of the other leg. Aim for 90%.',
        );
      }
    }

    if (order >= RehabPhase.neuromuscularControl.order) {
      if (goal.includesLanding && !status.goodLandingControl) {
        add(
          FocusAreaType.landing,
          FocusPriority.medium,
          'Land with control',
          'Controlled landing is not confirmed yet.',
        );
      }
      if (goal.includesRunning &&
          !(status.ptClearedForRunning && status.completedJogRunProgram)) {
        add(
          FocusAreaType.runningReadiness,
          FocusPriority.medium,
          'Prepare for running',
          status.ptClearedForRunning
              ? 'You are cleared to run. Build up with walk/jog without pain.'
              : 'Your physio has not cleared you to run yet.',
        );
      }
      final hop = status.hopSymmetry;
      if (goal.includesPlyometrics && hop != null && hop < 90) {
        add(
          FocusAreaType.hopSymmetry,
          FocusPriority.medium,
          'Close the hop gap',
          'Hop distance is $hop% of the other leg. Aim for 90%.',
        );
      }
    }

    final rsi = status.aclRsi;
    if (status.confidence <= 4 ||
        (rsi != null &&
            rsi < 60 &&
            order >= RehabPhase.advancedStrength.order)) {
      add(
        FocusAreaType.confidence,
        status.confidence <= 2 ? FocusPriority.high : FocusPriority.medium,
        'Rebuild confidence',
        'Confidence is ${status.confidence}/10. Harder drills wait until easier ones feel safe.',
      );
    }

    areas.sort((a, b) {
      final byPriority = b.priority.weight.compareTo(a.priority.weight);
      return byPriority != 0
          ? byPriority
          : a.type.index.compareTo(b.type.index);
    });
    return areas;
  }
}
