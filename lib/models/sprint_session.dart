import 'dart:math';

/// Model class representing a sprint session
class SprintSession {
  final DateTime date;
  final bool completed;
  final DateTime? completedAt;

  SprintSession({
    required this.date,
    this.completed = false,
    this.completedAt,
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
    );
  }

  /// Convert SprintSession to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'completed': completed,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  SprintSession copyWith({
    DateTime? date,
    bool? completed,
    DateTime? completedAt,
  }) {
    return SprintSession(
      date: date ?? this.date,
      completed: completed ?? this.completed,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Mark this sprint as completed
  SprintSession markCompleted() {
    return copyWith(
      completed: true,
      completedAt: DateTime.now(),
    );
  }

  @override
  String toString() {
    return 'SprintSession(date: $dateOnly, completed: $completed)';
  }
}

/// Helper class to generate and manage sprint schedules
class SprintScheduler {
  /// Generate two random sprint days for a given month
  /// Ensures at least 7 days between sprints
  static List<DateTime> generateSprintDaysForMonth(int year, int month, {Random? random}) {
    random ??= Random();
    
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;

    // We need at least 14 days in the available period to have 2 sprints with 7 days gap
    // Split the month into two halves to ensure spacing
    
    // First sprint: randomly in first half of month (day 1-14 or so)
    final firstHalfEnd = (daysInMonth / 2).floor();
    final firstSprintDay = random.nextInt(firstHalfEnd) + 1;
    
    // Second sprint: at least 7 days after first, but within the month
    final earliestSecondDay = firstSprintDay + 7;
    final latestSecondDay = daysInMonth;
    
    int secondSprintDay;
    if (earliestSecondDay <= latestSecondDay) {
      secondSprintDay = random.nextInt(latestSecondDay - earliestSecondDay + 1) + earliestSecondDay;
    } else {
      // Fallback: just use the last day of month
      secondSprintDay = daysInMonth;
    }

    return [
      DateTime(year, month, firstSprintDay),
      DateTime(year, month, secondSprintDay),
    ];
  }

  /// Check if sprint days need to be generated for the current month
  static bool needsSchedulingForMonth(List<SprintSession> existingSprints, int year, int month) {
    final monthSprints = existingSprints.where((s) {
      return s.date.year == year && s.date.month == month;
    }).toList();
    
    return monthSprints.length < 2;
  }

  /// Get upcoming sprints (today and future)
  static List<SprintSession> getUpcomingSprints(List<SprintSession> sprints) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return sprints
        .where((s) => !s.dateOnly.isBefore(today))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Get past sprints (not including today)
  static List<SprintSession> getPastSprints(List<SprintSession> sprints) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    return sprints
        .where((s) => s.dateOnly.isBefore(today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date)); // Most recent first
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

  SprintStatistics({
    required this.totalScheduled,
    required this.totalCompleted,
    required this.currentStreak,
    required this.longestStreak,
  });

  double get completionRate =>
      totalScheduled > 0 ? (totalCompleted / totalScheduled) * 100 : 0;

  factory SprintStatistics.empty() {
    return SprintStatistics(
      totalScheduled: 0,
      totalCompleted: 0,
      currentStreak: 0,
      longestStreak: 0,
    );
  }

  factory SprintStatistics.fromSprints(List<SprintSession> sprints) {
    if (sprints.isEmpty) return SprintStatistics.empty();

    // Only count past sprints for statistics (not future scheduled ones)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final pastSprints = sprints
        .where((s) => s.dateOnly.isBefore(today) || s.dateOnly.isAtSameMomentAs(today))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final completedSprints = pastSprints.where((s) => s.completed).toList();

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
    );
  }
}
