import 'dart:convert';
import 'dart:typed_data';

import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
import 'package:acl_rehab/domain/models/workout_log.dart';
import 'package:acl_rehab/domain/services/plan_generator.dart';
import 'package:acl_rehab/main.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'test_helpers.dart';

late AppStateRepository repository;
late Box<String> box;
var _boxCounter = 0;

Future<void> _openStorage({Map<String, String> seed = const {}}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  box = await Hive.openBox<String>(
    'flow_test_${_boxCounter++}',
    bytes: Uint8List(0),
  );
  for (final entry in seed.entries) {
    await box.put(entry.key, entry.value);
  }
  repository = AppStateRepository(box, prefs);
}

Widget _app() {
  return ProviderScope(
    overrides: [appStateRepositoryProvider.overrideWithValue(repository)],
    child: const ACLRecoveryCoachApp(),
  );
}

Finder _scrollable() => find.byType(Scrollable).first;

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: _scrollable());
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _tapTooltip(WidgetTester tester, String tooltip) async {
  final finder = find.byTooltip(tooltip);
  await _reveal(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

String _usDate(DateTime date) =>
    '${date.month.toString().padLeft(2, '0')}/'
    '${date.day.toString().padLeft(2, '0')}/${date.year}';

AppState _saved() => AppState.fromJson(
  jsonDecode(box.get('app_state_v2')!) as Map<String, dynamic>,
);

/// A saved state whose plan has one exercise per session: a single-leg
/// bridge dosed at 2 x 10 reps.
Map<String, dynamic> _bridgeState({List<WorkoutLog> logs = const []}) {
  final assessment = testAssessment(weeks: 12, readiness: loadingReadiness());
  final plan = PlanGenerator.generate(
    PlanGenerationInput(assessment: assessment, progressions: const {}),
  ).toJson();
  for (final session in plan['sessions'] as List<dynamic>) {
    final exercises = session['exercises'] as List<dynamic>;
    final bridge = Map<String, dynamic>.from(exercises.first as Map)
      ..['exerciseId'] = 'single-leg-bridge'
      ..['substitutedFromId'] = null;
    final prescription = Map<String, dynamic>.from(
      bridge['prescription'] as Map,
    );
    prescription
      ..['sets'] = 2
      ..['reps'] = '10'
      ..['hold'] = 'None';
    bridge['prescription'] = prescription;
    session['exercises'] = [bridge];
  }
  return {
    ...AppState(
      assessment: assessment,
      assessmentUpdatedAt: DateTime.now(),
      onboardingCompleted: true,
      workoutLogs: logs,
    ).toJson(),
    'plans': [plan],
  };
}

void main() {
  testWidgets(
    'assessment -> personalized plan -> workout -> progress -> reassessment',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2700);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.runAsync(_openStorage);

      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.text('Surgery Timeline'), findsOneWidget);

      // Surgery 13 weeks ago, typed into the date picker's input mode.
      await tester.tap(find.text('Select surgery date'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Switch to input'));
      await tester.pumpAndSettle();
      final surgery = DateTime.now().subtract(const Duration(days: 13 * 7 + 1));
      await tester.enterText(find.byType(TextField).last, _usDate(surgery));
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('You are 13 weeks post-op'), findsOneWidget);
      await _next(tester);

      await _tapText(tester, 'Patellar Tendon (BTB)');
      await _next(tester);

      // Quiet knee with full range and normal walking.
      await tester.drag(find.byType(Slider).first, const Offset(-400, 0));
      await tester.pumpAndSettle();
      await _tapText(tester, 'None');
      await _tapText(tester, 'Can you fully straighten the knee?');
      await _tapText(tester, 'Can you bend the knee functionally?');
      await _tapText(tester, 'Full');
      await _tapText(tester, 'Normal');
      await _next(tester);

      await _tapText(tester, 'Straight leg raise without lag?');
      await _tapText(tester, 'Strong quad set?');
      await _tapText(tester, 'No pain or swelling increase after exercise?');
      await _tapText(tester, 'Knee bending close to the other side?');
      await _tapText(tester, 'Pain-free loading activities?');
      await _tapText(tester, 'Measured results (optional)');
      final quadCard = find.ancestor(
        of: find.text('Quadriceps strength symmetry'),
        matching: find.byType(Card),
      );
      await _reveal(tester, quadCard);
      await tester.tap(
        find.descendant(of: quadCard, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();
      expect(find.text('70%'), findsOneWidget);
      await _next(tester);

      expect(find.text('Restrictions'), findsOneWidget);
      await _next(tester);

      await _tapText(tester, 'Return to sport');
      await _tapText(tester, 'Resistance band');
      await _next(tester);

      // The review previews a plan built from these answers.
      expect(find.text('Your Plan'), findsOneWidget);
      expect(find.text('Advanced Strength'), findsOneWidget);
      expect(find.text('Close the quadriceps gap'), findsOneWidget);
      await tester.tap(find.text('Create my plan'));
      await tester.pumpAndSettle();

      // Plan tab opens after onboarding.
      expect(find.text('Your Plan'), findsOneWidget);
      expect(find.textContaining('Version 1'), findsOneWidget);
      var saved = _saved();
      expect(saved.plans, hasLength(1));
      expect(saved.assessmentHistory, hasLength(1));
      final planIds = saved.activePlan!.exerciseIds;
      expect(planIds, contains('bodyweight-tempo-squat'));
      expect(planIds, isNot(contains('goblet-box-squat')));
      await _reveal(tester, find.text('Plan quality check'));

      // Workout: log sets and feedback, swap one exercise for today.
      await tester.tap(find.text('Workout').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Exercise 1 of'), findsOneWidget);
      // Reps and weight are entered for each set.
      final repsFields = find.widgetWithText(TextField, 'Reps');
      final weightFields = find.widgetWithText(TextField, 'kg');
      await _reveal(tester, repsFields.first);
      expect(weightFields, findsWidgets);
      await tester.enterText(repsFields.at(0), '10');
      await tester.enterText(weightFields.at(0), '5');
      await _tapTooltip(tester, 'Complete set 1');
      await _tapTooltip(tester, 'Complete set 2');
      expect(find.byTooltip('Undo set 1'), findsOneWidget);
      await _tapText(tester, 'Just Right');
      expect(find.textContaining('Holding this dose'), findsOneWidget);

      await tester.tap(find.text('Next exercise'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Swap exercise');
      expect(find.textContaining('Alternatives to'), findsOneWidget);
      await tester.tap(find.text('Use today').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Swapped in for today'), findsOneWidget);
      await _tapTooltip(tester, 'Complete set 1');

      await _tapText(tester, 'Finish workout early');
      expect(find.text('Save workout'), findsOneWidget);
      await tester.tap(find.text('Save workout'));
      await tester.pumpAndSettle();
      expect(find.text('Workout saved'), findsOneWidget);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      saved = _saved();
      expect(saved.workoutLogs, hasLength(1));
      final log = saved.workoutLogs.single;
      expect(log.completedSets, 3);
      final firstSet = log.entries.first.sets.first;
      expect(firstSet.reps, 10);
      expect(firstSet.weightKg, 5);
      expect(log.entries.first.sets, hasLength(2));
      expect(
        log.entries.where((entry) => entry.substitutedFromId != null),
        hasLength(1),
      );
      expect(saved.sessionLogs.single.workoutId, log.id);

      // Progress reflects the logged workout.
      await tester.tap(find.text('Progress').last);
      await tester.pumpAndSettle();
      expect(find.text('Progress'), findsWidgets);
      await _reveal(tester, find.text('Recent workouts'));
      expect(find.textContaining('3/'), findsWidgets);

      // Reassessment with a stronger quadriceps result.
      await tester.drag(_scrollable(), const Offset(0, 3000));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reassess'));
      await tester.pumpAndSettle();
      expect(find.text('Reassessment'), findsOneWidget);
      await _next(tester);
      final quadSlider = find.descendant(
        of: find.ancestor(
          of: find.text('Quadriceps strength symmetry'),
          matching: find.byType(Card),
        ),
        matching: find.byType(Slider),
      );
      await _reveal(tester, quadSlider);
      final track = tester.getRect(quadSlider);
      await tester.tapAt(
        Offset(track.right - track.width * 0.12, track.center.dy),
      );
      await tester.pumpAndSettle();
      await _next(tester);
      await _next(tester);
      await _next(tester);
      expect(find.text('Changes since your last assessment'), findsOneWidget);
      await tester.tap(find.text('Save and update plan'));
      await tester.pumpAndSettle();

      expect(find.text('Reassessment results'), findsOneWidget);
      expect(find.text('What improved'), findsOneWidget);
      expect(find.text('Quadriceps symmetry'), findsOneWidget);
      saved = _saved();
      expect(
        saved
            .assessmentHistory
            .last
            .assessment
            .protocolReadiness
            .quadStrengthSymmetry,
        greaterThan(80),
      );
      expect(saved.assessmentHistory, hasLength(2));
      expect(saved.plans, hasLength(2));
      expect(saved.activePlan!.trigger.name, 'reassessment');

      await _tapText(tester, 'View updated plan');
      expect(find.textContaining('Version 2'), findsOneWidget);
    },
  );

  testWidgets('single-leg exercise logs both legs and shows symmetry', (
    tester,
  ) async {
    await tester.runAsync(
      () => _openStorage(seed: {'app_state_v2': jsonEncode(_bridgeState())}),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Workout').last);
    await tester.pumpAndSettle();
    expect(find.text('Single-Leg Bridge'), findsWidgets);
    final repsFields = find.widgetWithText(TextField, 'Reps');
    await _reveal(tester, repsFields.first);
    expect(find.text('Operated'), findsWidgets);
    expect(find.text('Other'), findsWidgets);
    // The other leg is never prefilled, so untouched sets cannot fake 100%.
    final otherSet1 = tester.widget<TextField>(repsFields.at(1));
    expect(otherSet1.controller!.text, isEmpty);
    await tester.enterText(repsFields.at(0), '8');
    await tester.enterText(repsFields.at(1), '10');
    await _tapTooltip(tester, 'Complete set 1');
    expect(find.text('80% symmetry'), findsOneWidget);
    // The other leg may be skipped; nothing is stored for it.
    await tester.enterText(repsFields.at(2), '9');
    await _tapTooltip(tester, 'Complete set 2');
    expect(find.byTooltip('Undo set 2'), findsOneWidget);

    await _tapText(tester, 'Finish workout');
    await tester.tap(find.text('Save workout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    final entry = _saved().workoutLogs.single.entries.single;
    expect(entry.exerciseId, 'single-leg-bridge');
    expect(entry.sets.map((set) => set.reps), [8, 9]);
    expect(entry.otherLegSets.single.reps, 10);
  });

  testWidgets('training symmetry suggests a prefilled check-in', (
    tester,
  ) async {
    WorkoutLog bridge(int daysAgo, int operatedReps) {
      final at = DateTime.now().subtract(Duration(days: daysAgo));
      return WorkoutLog(
        id: 'w-$daysAgo',
        planId: 'p',
        planVersion: 1,
        sessionId: 'A',
        sessionName: 'Session A',
        startedAt: at,
        completedAt: at,
        entries: [
          WorkoutExerciseEntry(
            exerciseId: 'single-leg-bridge',
            exerciseName: 'Single-Leg Bridge',
            plannedSets: 2,
            completedSets: 1,
            sets: [SetLog(reps: operatedReps)],
            otherLegSets: const [SetLog(reps: 10)],
          ),
        ],
        painAfter: 1,
        effort: 5,
      );
    }

    final seed = _bridgeState(logs: [bridge(2, 8), bridge(1, 9)]);
    await tester.runAsync(
      () => _openStorage(seed: {'app_state_v2': jsonEncode(seed)}),
    );
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    await _reveal(tester, find.text('Training symmetry'));
    expect(find.textContaining('Hip 85%'), findsWidgets);
    await _tapText(tester, 'Review check-in');
    expect(find.textContaining('From training'), findsOneWidget);
    final save = find.text('Save check-in');
    await tester.scrollUntilVisible(
      save,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(save);
    await tester.pumpAndSettle();

    final checkIn = _saved().milestoneCheckIns.last;
    expect(checkIn.hipStrengthSymmetry, 85);
  });

  testWidgets('saved data from the previous version is migrated', (
    tester,
  ) async {
    final legacy = {
      'assessment': testAssessment(weeks: 9).toJson()..remove('profile'),
      'assessmentUpdatedAt': DateTime.now().toIso8601String(),
      'onboardingCompleted': true,
      'selectedIndex': 0,
      'themeMode': 'system',
      'sessionLogs': [],
      'exerciseProgressions': {},
      'milestoneCheckIns': [],
    };
    await tester.runAsync(
      () => _openStorage(seed: {'app_state_v2': jsonEncode(legacy)}),
    );

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('Today'), findsWidgets);
    expect(find.text('Personalize your plan'), findsOneWidget);
    final saved = _saved();
    expect(saved.plans, hasLength(1));
    expect(saved.assessmentHistory, hasLength(1));
    expect(saved.assessment!.profile.isDefault, isTrue);
  });
}
