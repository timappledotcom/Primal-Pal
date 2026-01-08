/// Model representing a historical record of a completed exercise
class ExerciseHistoryEntry {
  final String id;
  final String exerciseId;
  final String exerciseName;
  final DateTime completedAt;

  ExerciseHistoryEntry({
    required this.id,
    required this.exerciseId,
    required this.exerciseName,
    required this.completedAt,
  });

  factory ExerciseHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseHistoryEntry(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      exerciseName: json['exerciseName'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'completedAt': completedAt.toIso8601String(),
    };
  }
}
