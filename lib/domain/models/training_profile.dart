enum RecoveryGoal { dailyActivities, fitness, running, returnToSport }

/// Equipment beyond household basics. A towel, chair, stairs or a low step,
/// floor space, a wall or counter, and a flat walking route are assumed.
enum EquipmentType {
  resistanceBand,
  dumbbells,
  gymMachines,
  foamPad,
  stationaryBike,
  openSpace,
  partner,
  barbell,
}

extension RecoveryGoalX on RecoveryGoal {
  String get label {
    switch (this) {
      case RecoveryGoal.dailyActivities:
        return 'Everyday function';
      case RecoveryGoal.fitness:
        return 'General fitness';
      case RecoveryGoal.running:
        return 'Running';
      case RecoveryGoal.returnToSport:
        return 'Return to sport';
    }
  }

  String get description {
    switch (this) {
      case RecoveryGoal.dailyActivities:
        return 'Walk, climb stairs, and move comfortably day to day.';
      case RecoveryGoal.fitness:
        return 'Gym, cycling, swimming, or recreational activity without cutting.';
      case RecoveryGoal.running:
        return 'Straight-line jogging or running.';
      case RecoveryGoal.returnToSport:
        return 'Sport with jumping, cutting, or pivoting.';
    }
  }

  /// Whether the goal needs straight-line running work in late phases.
  bool get includesRunning =>
      this == RecoveryGoal.running ||
      this == RecoveryGoal.returnToSport ||
      this == RecoveryGoal.fitness;

  /// Whether the goal needs hopping and bounding.
  bool get includesPlyometrics =>
      this == RecoveryGoal.running || this == RecoveryGoal.returnToSport;

  /// Whether the goal needs cutting, pivoting, and agility drills.
  bool get includesChangeOfDirection => this == RecoveryGoal.returnToSport;

  /// Whether the goal needs landing mechanics practice.
  bool get includesLanding => this != RecoveryGoal.dailyActivities;
}

extension EquipmentTypeX on EquipmentType {
  String get label {
    switch (this) {
      case EquipmentType.resistanceBand:
        return 'Resistance band';
      case EquipmentType.dumbbells:
        return 'Dumbbells or kettlebell';
      case EquipmentType.gymMachines:
        return 'Gym machines';
      case EquipmentType.foamPad:
        return 'Foam balance pad';
      case EquipmentType.stationaryBike:
        return 'Stationary bike';
      case EquipmentType.openSpace:
        return 'Open space (15-20 m)';
      case EquipmentType.partner:
        return 'Partner or PT';
      case EquipmentType.barbell:
        return 'Barbell or trap bar';
    }
  }

  String get description {
    switch (this) {
      case EquipmentType.resistanceBand:
        return 'Loop or long band';
      case EquipmentType.dumbbells:
        return 'Any hand-held weight';
      case EquipmentType.gymMachines:
        return 'Leg press, hamstring curl';
      case EquipmentType.foamPad:
        return 'Firm foam or balance cushion';
      case EquipmentType.stationaryBike:
        return 'Upright or recumbent';
      case EquipmentType.openSpace:
        return 'Field, court, or track for running drills';
      case EquipmentType.partner:
        return 'Someone to assist balance drills';
      case EquipmentType.barbell:
        return 'With plates, ideally a rack';
    }
  }
}

class TrainingProfile {
  const TrainingProfile({
    this.goal = RecoveryGoal.fitness,
    this.sport = '',
    this.sessionsPerWeek = 3,
    this.minutesPerSession = 30,
    this.equipment = const {},
    this.isDefault = false,
  });

  /// Profile used for data saved before goals and equipment were collected.
  /// It keeps the previous behavior (every exercise available) and is flagged
  /// so the app can ask the user to personalize it.
  factory TrainingProfile.legacyDefault() {
    return TrainingProfile(
      goal: RecoveryGoal.returnToSport,
      equipment: EquipmentType.values.toSet(),
      isDefault: true,
    );
  }

  static const minSessionsPerWeek = 2;
  static const maxSessionsPerWeek = 6;
  static const sessionLengthOptions = [15, 20, 30, 45, 60];

  final RecoveryGoal goal;
  final String sport;
  final int sessionsPerWeek;
  final int minutesPerSession;
  final Set<EquipmentType> equipment;
  final bool isDefault;

  bool has(EquipmentType type) => equipment.contains(type);

  bool hasAll(Iterable<EquipmentType> required) => required.every(has);

  String get goalSummary {
    final trimmed = sport.trim();
    if (goal == RecoveryGoal.returnToSport && trimmed.isNotEmpty) {
      return '${goal.label} ($trimmed)';
    }
    return goal.label;
  }

  TrainingProfile copyWith({
    RecoveryGoal? goal,
    String? sport,
    int? sessionsPerWeek,
    int? minutesPerSession,
    Set<EquipmentType>? equipment,
    bool? isDefault,
  }) {
    return TrainingProfile(
      goal: goal ?? this.goal,
      sport: sport ?? this.sport,
      sessionsPerWeek: sessionsPerWeek ?? this.sessionsPerWeek,
      minutesPerSession: minutesPerSession ?? this.minutesPerSession,
      equipment: equipment ?? this.equipment,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'goal': goal.name,
      'sport': sport,
      'sessionsPerWeek': sessionsPerWeek,
      'minutesPerSession': minutesPerSession,
      'equipment': equipment.map((item) => item.name).toList(),
      'isDefault': isDefault,
    };
  }

  factory TrainingProfile.fromJson(Map<String, dynamic> data) {
    final rawEquipment = data['equipment'] as List<dynamic>? ?? const [];
    return TrainingProfile(
      goal: RecoveryGoal.values.firstWhere(
        (item) => item.name == data['goal'],
        orElse: () => RecoveryGoal.fitness,
      ),
      sport: data['sport'] as String? ?? '',
      sessionsPerWeek: ((data['sessionsPerWeek'] as int?) ?? 3).clamp(
        minSessionsPerWeek,
        maxSessionsPerWeek,
      ),
      minutesPerSession: (data['minutesPerSession'] as int?) ?? 30,
      equipment: {
        for (final raw in rawEquipment)
          for (final item in EquipmentType.values)
            if (item.name == raw) item,
      },
      isDefault: data['isDefault'] as bool? ?? false,
    );
  }
}
