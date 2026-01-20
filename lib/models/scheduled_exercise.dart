/// Model class representing an exercise scheduled for a specific session
class ScheduledExercise {
  final String exerciseId;
  final String exerciseName;
  final DateTime scheduledTime;
  final int notificationId;
  /// Session: 'morning' or 'afternoon'
  final String session;
  bool isSnoozed;
  DateTime? originalTime;
  bool isCompleted;

  ScheduledExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.scheduledTime,
    required this.notificationId,
    this.session = 'morning',
    this.isSnoozed = false,
    this.originalTime,
    this.isCompleted = false,
  });

  /// Create ScheduledExercise from JSON map
  factory ScheduledExercise.fromJson(Map<String, dynamic> json) {
    return ScheduledExercise(
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      scheduledTime: DateTime.parse(json['scheduledTime'] as String),
      notificationId: json['notificationId'] as int,
      session: json['session'] as String? ?? 'morning',
      isSnoozed: json['isSnoozed'] as bool? ?? false,
      originalTime: json['originalTime'] != null
          ? DateTime.parse(json['originalTime'] as String)
          : null,
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }

  /// Convert ScheduledExercise to JSON map
  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'scheduledTime': scheduledTime.toIso8601String(),
      'notificationId': notificationId,
      'session': session,
      'isSnoozed': isSnoozed,
      'originalTime': originalTime?.toIso8601String(),
      'isCompleted': isCompleted,
    };
  }

  /// Get formatted time string (e.g., "2:30 PM")
  String get formattedTime {
    final hour = scheduledTime.hour;
    final minute = scheduledTime.minute;
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    final displayMinute = minute.toString().padLeft(2, '0');
    return '$displayHour:$displayMinute $period';
  }

  /// Check if this scheduled exercise is in the past
  bool get isPast => scheduledTime.isBefore(DateTime.now());

  /// Check if this scheduled exercise is upcoming (within next hour)
  bool get isUpcoming {
    final now = DateTime.now();
    final diff = scheduledTime.difference(now);
    return diff.inMinutes > 0 && diff.inMinutes <= 60;
  }

  /// Create a snoozed copy of this exercise
  ScheduledExercise snooze(int minutes) {
    return ScheduledExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      scheduledTime: DateTime.now().add(Duration(minutes: minutes)),
      notificationId: notificationId,
      session: session,
      isSnoozed: true,
      originalTime: originalTime ?? scheduledTime,
      isCompleted: isCompleted,
    );
  }

  /// Create a completed copy of this exercise
  ScheduledExercise markCompleted() {
    return ScheduledExercise(
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      scheduledTime: scheduledTime,
      notificationId: notificationId,
      session: session,
      isSnoozed: isSnoozed,
      originalTime: originalTime,
      isCompleted: true,
    );
  }

  @override
  String toString() {
    return 'ScheduledExercise(name: $exerciseName, time: $formattedTime, snoozed: $isSnoozed, completed: $isCompleted)';
  }
}
