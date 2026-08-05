import 'package:acl_rehab/data/repositories/app_state_repository.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  final stateBox = await Hive.openBox<String>(AppStateRepository.boxName);
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(
          AppStateRepository(stateBox, prefs),
        ),
      ],
      child: const MaterialApp(home: OnboardingScreen()),
    ),
  );
}
