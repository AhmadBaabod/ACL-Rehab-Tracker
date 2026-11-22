import 'package:flutter/material.dart';

/// Bottom-navigation destinations, in display order. The index is persisted.
enum AppTab { today, plan, workout, progress, about }

extension AppTabX on AppTab {
  String get label {
    switch (this) {
      case AppTab.today:
        return 'Today';
      case AppTab.plan:
        return 'Plan';
      case AppTab.workout:
        return 'Workout';
      case AppTab.progress:
        return 'Progress';
      case AppTab.about:
        return 'About';
    }
  }

  IconData get icon {
    switch (this) {
      case AppTab.today:
        return Icons.today_outlined;
      case AppTab.plan:
        return Icons.assignment_outlined;
      case AppTab.workout:
        return Icons.sports_gymnastics_outlined;
      case AppTab.progress:
        return Icons.insights_outlined;
      case AppTab.about:
        return Icons.info_outline;
    }
  }

  IconData get selectedIcon {
    switch (this) {
      case AppTab.today:
        return Icons.today;
      case AppTab.plan:
        return Icons.assignment;
      case AppTab.workout:
        return Icons.sports_gymnastics;
      case AppTab.progress:
        return Icons.insights;
      case AppTab.about:
        return Icons.info;
    }
  }
}
