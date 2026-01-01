/// Model class representing a daily walk log entry with accumulated time
class DailyWalk {
  final DateTime date;

  /// Total accumulated walking time in seconds for this day
  final int totalSeconds;

  final String? notes;

  DailyWalk({
    required this.date,
    this.totalSeconds = 0,
    this.notes,
  });

  /// Whether walking was done today (any time accumulated)
  bool get completed => totalSeconds > 0;

  /// Duration in minutes (for backward compatibility and display)
  int get durationMinutes => (totalSeconds / 60).floor();

  /// Get the date without time component (for comparison)
  DateTime get dateOnly => DateTime(date.year, date.month, date.day);

  /// Format the total time as HH:MM:SS
  String get formattedTime {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create DailyWalk from JSON map
  factory DailyWalk.fromJson(Map<String, dynamic> json) {
    // Handle migration from old format (completed + durationMinutes) to new format (totalSeconds)
    int totalSeconds = 0;
    if (json.containsKey('totalSeconds')) {
      totalSeconds = json['totalSeconds'] as int;
    } else if (json['completed'] == true && json['durationMinutes'] != null) {
      // Migrate old data: convert minutes to seconds
      totalSeconds = (json['durationMinutes'] as int) * 60;
    }

    return DailyWalk(
      date: DateTime.parse(json['date'] as String),
      totalSeconds: totalSeconds,
      notes: json['notes'] as String?,
    );
  }

  /// Convert DailyWalk to JSON map
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'totalSeconds': totalSeconds,
      'notes': notes,
    };
  }

  /// Create a copy with updated fields
  DailyWalk copyWith({
    DateTime? date,
    int? totalSeconds,
    String? notes,
  }) {
    return DailyWalk(
      date: date ?? this.date,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      notes: notes ?? this.notes,
    );
  }

  /// Add seconds to the accumulated time
  DailyWalk addSeconds(int seconds) {
    return copyWith(totalSeconds: totalSeconds + seconds);
  }

  /// Check if this walk is from today
  bool get isToday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dateOnly.isAtSameMomentAs(today);
  }

  /// Check if this walk is from a specific date
  bool isOnDate(DateTime other) {
    final otherDateOnly = DateTime(other.year, other.month, other.day);
    return dateOnly.isAtSameMomentAs(otherDateOnly);
  }

  @override
  String toString() {
    return 'DailyWalk(date: $dateOnly, totalSeconds: $totalSeconds, formatted: $formattedTime)';
  }
}

/// Statistics for walks over a period
class WalkStatistics {
  final int totalDays;
  final int completedDays;
  final int totalSeconds;
  final int currentStreak;
  final int longestStreak;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  WalkStatistics({
    required this.totalDays,
    required this.completedDays,
    required this.totalSeconds,
    required this.currentStreak,
    required this.longestStreak,
    this.periodStart,
    this.periodEnd,
  });

  /// Completion rate as a percentage (0-100)
  double get completionRate =>
      totalDays > 0 ? (completedDays / totalDays) * 100 : 0;

  /// Average duration per walk in seconds
  double get averageDurationSeconds =>
      completedDays > 0 ? totalSeconds / completedDays : 0;

  /// Average duration per walk in minutes
  double get averageDuration => averageDurationSeconds / 60;

  /// Total minutes walked
  int get totalMinutes => (totalSeconds / 60).floor();

  /// Format average time as MM:SS
  String get formattedAverageTime {
    final avgSeconds = averageDurationSeconds.round();
    final minutes = avgSeconds ~/ 60;
    final seconds = avgSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Create empty statistics
  factory WalkStatistics.empty() {
    return WalkStatistics(
      totalDays: 0,
      completedDays: 0,
      totalSeconds: 0,
      currentStreak: 0,
      longestStreak: 0,
    );
  }

  /// Calculate statistics from a list of walks
  factory WalkStatistics.fromWalks(
    List<DailyWalk> walks, {
    DateTime? periodStart,
    DateTime? periodEnd,
  }) {
    if (walks.isEmpty) return WalkStatistics.empty();

    // Sort by date descending
    final sorted = List<DailyWalk>.from(walks)
      ..sort((a, b) => b.date.compareTo(a.date));

    final completedWalks = sorted.where((w) => w.completed).toList();
    final totalSeconds = completedWalks.fold<int>(
      0,
      (sum, w) => sum + w.totalSeconds,
    );

    // Calculate current streak (consecutive days from today)
    int currentStreak = 0;
    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);

    for (final walk in sorted) {
      if (walk.completed && walk.dateOnly.isAtSameMomentAs(checkDate)) {
        currentStreak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else if (walk.dateOnly.isBefore(checkDate)) {
        break;
      }
    }

    // Calculate longest streak
    int longestStreak = 0;
    int tempStreak = 0;
    DateTime? lastDate;

    for (final walk in sorted.reversed) {
      if (walk.completed) {
        if (lastDate == null ||
            walk.dateOnly.difference(lastDate).inDays == 1) {
          tempStreak++;
          longestStreak =
              tempStreak > longestStreak ? tempStreak : longestStreak;
        } else {
          tempStreak = 1;
        }
        lastDate = walk.dateOnly;
      } else {
        tempStreak = 0;
        lastDate = null;
      }
    }

    return WalkStatistics(
      totalDays: walks.length,
      completedDays: completedWalks.length,
      totalSeconds: totalSeconds,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      periodStart: periodStart,
      periodEnd: periodEnd,
    );
  }
}
