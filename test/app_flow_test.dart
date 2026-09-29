import 'dart:convert';
import 'dart:typed_data';

import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/domain/models/app_state.dart';
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
      await _tapText(tester, 'Set 1');
      await _tapText(tester, 'Set 2');
      await _tapText(tester, 'Just Right');
      expect(find.textContaining('Holding this dose'), findsOneWidget);

      await tester.tap(find.text('Next exercise'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Swap exercise');
      expect(find.textContaining('Alternatives to'), findsOneWidget);
      await tester.tap(find.text('Use today').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Swapped in for today'), findsOneWidget);
      await _tapText(tester, 'Set 1');

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
