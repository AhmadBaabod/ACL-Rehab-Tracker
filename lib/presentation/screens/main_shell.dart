import 'package:acl_rehab/core/navigation/app_tabs.dart';
import 'package:acl_rehab/presentation/providers/app_state_provider.dart';
import 'package:acl_rehab/presentation/screens/about_screen.dart';
import 'package:acl_rehab/presentation/screens/dashboard_screen.dart';
import 'package:acl_rehab/presentation/screens/plan_screen.dart';
import 'package:acl_rehab/presentation/screens/progress_screen.dart';
import 'package:acl_rehab/presentation/screens/session_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  static const _screens = [
    DashboardScreen(),
    PlanScreen(),
    SessionScreen(),
    ProgressScreen(),
    AboutScreen(),
  ];

  /// Width at which the bottom bar becomes a side rail.
  static const _railBreakpoint = 900.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appStateAsync = ref.watch(appControllerProvider);

    return appStateAsync.when(
      data: (appState) {
        final currentIndex = appState.selectedIndex
            .clamp(0, _screens.length - 1)
            .toInt();
        void select(int index) =>
            ref.read(appControllerProvider.notifier).updateSelectedIndex(index);
        final body = IndexedStack(index: currentIndex, children: _screens);

        return LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= _railBreakpoint) {
              return Scaffold(
                body: Row(
                  children: [
                    NavigationRail(
                      selectedIndex: currentIndex,
                      onDestinationSelected: select,
                      labelType: NavigationRailLabelType.all,
                      destinations: [
                        for (final tab in AppTab.values)
                          NavigationRailDestination(
                            icon: Icon(tab.icon),
                            selectedIcon: Icon(tab.selectedIcon),
                            label: Text(tab.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body),
                  ],
                ),
              );
            }
            return Scaffold(
              body: body,
              bottomNavigationBar: NavigationBar(
                selectedIndex: currentIndex,
                onDestinationSelected: select,
                destinations: [
                  for (final tab in AppTab.values)
                    NavigationDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.selectedIcon),
                      label: tab.label,
                    ),
                ],
              ),
            );
          },
        );
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Unable to load your data: $error')),
      ),
    );
  }
}
