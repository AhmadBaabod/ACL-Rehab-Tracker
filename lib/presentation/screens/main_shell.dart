import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/about_screen.dart';
import 'package:acl_rehab/presentation/screens/dashboard_screen.dart';
import 'package:acl_rehab/presentation/screens/progress_screen.dart';
import 'package:acl_rehab/presentation/screens/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final List<Widget> _screens = [
    const DashboardScreen(),
    const SessionScreen(),
    const ProgressScreen(),
    const AboutScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    try {
      final appStateAsync = ref.watch(appControllerProvider);

      return appStateAsync.when(
        data: (appState) {
          final currentIndex = appState.selectedIndex
              .clamp(0, _screens.length - 1)
              .toInt();
          return Scaffold(
            body: IndexedStack(index: currentIndex, children: _screens),
            bottomNavigationBar: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) async {
                await ref
                    .read(appControllerProvider.notifier)
                    .updateSelectedIndex(index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(Icons.sports_gymnastics_outlined),
                  selectedIcon: Icon(Icons.sports_gymnastics),
                  label: 'Session',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights),
                  label: 'Progress',
                ),
                NavigationDestination(
                  icon: Icon(Icons.info_outline),
                  selectedIcon: Icon(Icons.info),
                  label: 'About',
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (error, stack) => Scaffold(
          body: Center(child: Text('Unable to load app state: $error')),
        ),
      );
    } catch (error, stack) {
      debugPrint('MainShell build failed: $error');
      debugPrintStack(stackTrace: stack);
      return const Scaffold(
        body: Center(child: Text('The main shell failed to initialize.')),
      );
    }
  }
}
