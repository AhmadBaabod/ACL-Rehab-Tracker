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
        'Instability or locking reported',
        'Instability, locking, or giving way needs clinical review. The plan '
            'stays with protected motion work until it is assessed.',
      );
    }
    if (!status.fullExtension) {
      add(
        FocusAreaType.extension,
        FocusPriority.high,
        'Restore full extension',
        'The knee does not fully straighten yet. Full extension is the first '
            'priority after ACL reconstruction.',
      );
    }
    if (!status.functionalFlexion) {
      add(
        FocusAreaType.flexion,
        status.weeksPostOp >= 6 ? FocusPriority.high : FocusPriority.medium,
        'Improve knee bending',
        status.readinessKnown
            ? 'Bending is limited or not yet within about 10 degrees of the other knee.'
            : 'Knee bending is not yet functional.',
      );
    }
    if (status.swelling != Swelling.none) {
      add(
        FocusAreaType.swelling,
        status.swelling.severity >= Swelling.moderate.severity
            ? FocusPriority.high
            : FocusPriority.medium,
        'Settle swelling',
        '${status.swelling.label} swelling. Loading stays conservative and '
            'circulation work is added until it settles.',
      );
    }
    if (status.pain >= 3) {
      add(
        FocusAreaType.pain,
        status.pain >= 5 ? FocusPriority.high : FocusPriority.medium,
        'Keep pain controlled',
        'Pain is ${status.pain}/10. Exercise volume and effort are kept below '
            'the level that flares symptoms.',
      );
    }
    if (status.readinessKnown &&
        status.weeksPostOp < 16 &&
        (!status.straightLegRaiseNoLag || !status.strongQuadSet)) {
      final missing = [
        if (!status.straightLegRaiseNoLag) 'a straight leg raise without lag',
        if (!status.strongQuadSet) 'a strong quad set',
      ];
      add(
        FocusAreaType.quadActivation,
        order <= RehabPhase.earlyStrengthening.order
            ? FocusPriority.high
            : FocusPriority.medium,
        'Wake up the quadriceps',
        'You have not yet confirmed ${missing.join(' or ')}.',
      );
    }
    if (!status.normalWalking || !status.fullWeightBearing) {
      add(
        FocusAreaType.gait,
        order == 0 ? FocusPriority.high : FocusPriority.medium,
        'Normalize walking',
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
          'Build quadriceps strength',
          order >= RehabPhase.advancedStrength.order
              ? 'Quadriceps symmetry has not been measured. Ask your PT to test it; '
                    'quad weakness is the most common deficit after ACLR.'
              : 'Quadriceps weakness is the most common deficit after ACLR.',
        );
      } else if (quad < 80) {
        add(
          FocusAreaType.quadStrength,
          FocusPriority.high,
          'Close the quadriceps gap',
          'Quadriceps symmetry is $quad% (target 80% for this stage, 90% for sport).',
        );
      } else if (quad < 90 && order >= RehabPhase.neuromuscularControl.order) {
        add(
          FocusAreaType.quadStrength,
          FocusPriority.medium,
          'Close the quadriceps gap',
          'Quadriceps symmetry is $quad% (target 90% before return to sport).',
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
          'Hamstring symmetry is $hamstring% (target 80%, then 90%).',
        );
      } else if (hamstring != null &&
          hamstring < 90 &&
          order >= RehabPhase.neuromuscularControl.order) {
        add(
          FocusAreaType.hamstringStrength,
          FocusPriority.medium,
          'Build hamstring strength',
          'Hamstring symmetry is $hamstring% (target 90% before return to sport).',
        );
      } else if (hamstring == null && status.graftType == GraftType.hamstring) {
        add(
          FocusAreaType.hamstringStrength,
          FocusPriority.low,
          'Rebuild hamstring strength',
          'Hamstring grafts regain knee-flexor strength gradually.',
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
          'Hip/glute symmetry is $hip% (target 90%).',
        );
      }
      final balance = status.balanceSymmetry;
      if (balance != null && balance < 90) {
        add(
          FocusAreaType.balance,
          balance < 75 ? FocusPriority.high : FocusPriority.medium,
          'Improve single-leg balance',
          'Balance symmetry is $balance% (target 90%).',
        );
      }
    }

    if (order >= RehabPhase.neuromuscularControl.order) {
      if (goal.includesLanding && !status.goodLandingControl) {
        add(
          FocusAreaType.landing,
          FocusPriority.medium,
          'Refine landing control',
          'Controlled, symmetrical landing has not been confirmed yet.',
        );
      }
      if (goal.includesRunning &&
          !(status.ptClearedForRunning && status.completedJogRunProgram)) {
        add(
          FocusAreaType.runningReadiness,
          FocusPriority.medium,
          'Prepare for running',
          status.ptClearedForRunning
              ? 'Running is cleared; complete the walk/jog progression without symptoms.'
              : 'PT running clearance is not recorded yet.',
        );
      }
      final hop = status.hopSymmetry;
      if (goal.includesPlyometrics && hop != null && hop < 90) {
        add(
          FocusAreaType.hopSymmetry,
          FocusPriority.medium,
          'Close the hop-test gap',
          'Hop symmetry is $hop% (target 90%).',
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
        rsi != null && rsi < 60
            ? 'Confidence ${status.confidence}/10 and ACL-RSI $rsi. Harder '
                  'balance and landing variations wait until easier ones feel secure.'
            : 'Confidence is ${status.confidence}/10. Harder balance and landing '
                  'variations wait until easier ones feel secure.',
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
