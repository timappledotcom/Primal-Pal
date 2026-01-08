import 'dart:math';

/// Model class representing a sprint session
class SprintSession {
  final DateTime date;
  final bool completed;
  final DateTime? completedAt;
  final int? targetSets;
  final int completedSets;

  SprintSession({
    required this.date,
    this.completed = false,
    this.completedAt,
    this.targetSets,
    this.completedSets = 0,
  });

  /// Get the date without time component (for comparison)
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  /// Check if this sprint is scheduled for today
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateOnly.isAtSameMomentAs(today);
  }

  /// Check if this sprint is in the past (and not today)
  bool get isPast {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateOnly.isBefore(today);
  }

  /// Check if this sprint is in the future
  bool get isFuture {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateOnly.isAfter(today);
  }

  /// Create SprintSession from JSON map
  factory SprintSession.fromJson(Map<String, dynamic> json) {
    return SprintSession(
      date: DateTime.parse(json['date'] as String),
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      targetSets: json['targetSets'] as int?,
      completedSets: json['completedSets'] as int? ?? 0,
    );
  }

  /// Convert SprintSession to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
      'targetSets': targetSets,
      'completedSets': completedSets,
    };
  }

  /// Create a copy with updated fields
  SprintSession copyWith({
    DateTime? date,
    bool? completed,
    DateTime? completedAt,
    int? targetSets,
    int? completedSets,
  }) {
    return SprintSession(
      date: date ?? this.date,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
      targetSets: targetSets ?? this.targetSets,
      completedSets: completedSets ?? this.completedSets,
    );
  }
  
  /// Mark this sprint as completed
  SprintSession markCompleted() {
    return copyWith(
      completed: true,
      completedAt: DateTime.now(),
      // Ensure specific rep counts sync up if forcing completion
      completedSets: (targetSets != null && targetSets! > completedSets) ? targetSets : completedSets, 
    );
  }

  /// Increment completed set count
  SprintSession incrementSets() {
    final newCompletedSets = completedSets + 1;
    final isDone = targetSets != null && newCompletedSets >= targetSets!;
    
    return copyWith(
      completedSets: newCompletedSets,
      completed: isDone,
      completedAt: isDone ? DateTime.now() : null,
    );
  }

  @override
  String toString() {
    return 'SprintSession(date: $dateOnly, completed: $completed, sets: $completedSets/${targetSets ?? "?"})';
  }

  /// Get today's sprint if scheduled
  static SprintSession? getTodaysSprint(List<SprintSession> sprints) {
    try {
      return sprints.firstWhere((s) => s.isToday);
    } catch (_) {
      return null;
    }
  }
}

/// Statistics for sprint sessions
class SprintStatistics {
  final int totalScheduled;
  final int totalCompleted;
  final int currentStreak;
  final int longestStreak;
  final int completedChunks; // Individual sets/chunks
  final int missedChunks;

  SprintStatistics({
    required this.totalScheduled,
    required this.totalCompleted,
    required this.currentStreak,
    required this.longestStreak,
    this.completedChunks = 0,
    this.missedChunks = 0,
  });

  double get completionRate =>
      totalScheduled > 0 ? (totalCompleted / totalScheduled) * 100 : 0;

  factory SprintStatistics.empty() {
    return SprintStatistics(
      totalScheduled: 0,
      totalCompleted: 0,
      currentStreak: 0,
      longestStreak: 0,
      completedChunks: 0,
      missedChunks: 0,
    );
  }

  factory SprintStatistics.fromSprints(List<SprintSession> sprints) {
    if (sprints.isEmpty) return SprintStatistics.empty();

    // Only count past sprints for statistics (not future scheduled ones)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final pastSprints = sprints
        .where((s) =>
            s.dateOnly.isBefore(today) || s.dateOnly.isAtSameMomentAs(today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final completedSprints = pastSprints.where((s) => s.completed).toList();
    
    // Calculate chunks/sets stats
    int completedChunks = 0;
    int missedChunks = 0;
    
    for (final sprint in pastSprints) {
      completedChunks += sprint.completedSets;
      if (sprint.targetSets != null) {
        // If not completed or partially completed, add missing sets
        if (!sprint.completed || sprint.completedSets < sprint.targetSets!) {
           missedChunks += (sprint.targetSets! - sprint.completedSets);
        }
      } else {
        // Legacy support: if no target sets but marked incomplete, count as 1 missing chunk? 
        // Or assume legacy target was 1. Let's assume target was 1 for legacy.
        if (!sprint.completed) missedChunks++;
      }
    }

    // Calculate current streak (consecutive completed sprints from most recent)
    int currentStreak = 0;
    for (final sprint in pastSprints) {
      if (sprint.completed) {
        currentStreak++;
      } else if (sprint.isPast) {
        // If it's a past sprint that wasn't completed, streak is broken
        break;
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    final sortedByDate = List<SprintSession>.from(pastSprints)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final sprint in sortedByDate) {
      if (sprint.completed) {
        tempStreak++;
        if (tempStreak > longestStreak) {
          longestStreak = tempStreak;
        }
      } else {
        tempStreak = 0;
      }
    }

    return SprintStatistics(
      totalScheduled: pastSprints.length,
      totalCompleted: completedSprints.length,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      completedChunks: completedChunks,
      missedChunks: missedChunks,
    );
  }
}

/// Helper class to generate and manage sprint schedules
class SprintScheduler {
  static const int sprintsPerMonth = 2; // Bi-weekly approximately

  /// Generate sprint days for a given month
  static List<DateTime> generateSprintDaysForMonth(int year, int month) {
    final random = Random(year * 100 + month); // Determine seed based on month
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final days = <DateTime>[];

    // Simple strategy: Divide month into 2 halves and pick a random day in each
    // Day 1-15
    final firstHalfDay = random.nextInt(15) + 1;
    days.add(DateTime(year, month, firstHalfDay));

    // Day 16-End
    final secondHalfStart = 16;
    final remainingDays = daysInMonth - secondHalfStart;
    final secondHalfDay = secondHalfStart + random.nextInt(remainingDays + 1);
    days.add(DateTime(year, month, secondHalfDay));

    days.sort();
    return days;
  }
  
  /// check if scheduling is needed for this month
  static bool needsSchedulingForMonth(
      List<SprintSession> sprints, int year, int month) {
    return !sprints.any((s) => s.date.year == year && s.date.month == month);
  }

  /// Get today's sprint session if exists
  static SprintSession? getTodaysSprint(List<SprintSession> sprints) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    try {
      return sprints.firstWhere((s) =>
          s.date.year == today.year &&
          s.date.month == today.month &&
          s.date.day == today.day);
    } catch (_) {
      return null;
    }
  }

  /// Get upcoming sprints (including today)
  static List<SprintSession> getUpcomingSprints(List<SprintSession> sprints) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = sprints.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      return sDate.isAfter(today) || sDate.isAtSameMomentAs(today);
    }).toList();
    upcoming.sort((a, b) => a.date.compareTo(b.date));
    return upcoming;
  }

  /// Get past sprints
  static List<SprintSession> getPastSprints(List<SprintSession> sprints) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final past = sprints.where((s) {
      final sDate = DateTime(s.date.year, s.date.month, s.date.day);
      return sDate.isBefore(today);
    }).toList();
    past.sort((a, b) => b.date.compareTo(a.date));
    return past;
  }
}
