/// Enum representing the type of exercise
enum ExerciseType {
  strength,
  mobility,
}

/// Extension to provide display names and JSON conversion for ExerciseType
extension ExerciseTypeExtension on ExerciseType {
  String get displayName {
    switch (this) {
      case ExerciseType.strength:
        return 'Strength';
      case ExerciseType.mobility:
        return 'Mobility';
    }
  }

  String toJson() => name;

  static ExerciseType fromJson(String json) {
    return ExerciseType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => ExerciseType.strength,
    );
  }
}

/// Model class representing an exercise in the app
class Exercise {
  final String id;
  final String name;
  final String description;
  final ExerciseType type;

  /// For timed exercises, this is seconds. For rep exercises, this is reps.
  int currentReps;

  /// If true, currentReps represents seconds instead of repetitions
  final bool isTimed;

  /// If true, this exercise needs to be done on both sides (e.g., stretches)
  final bool isBilateral;

  /// If false, this exercise is excluded from the rotation
  bool isEnabled;
  final String relatedStretch;
  DateTime? lastPerformedDate;

  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.currentReps,
    this.isTimed = false,
    this.isBilateral = false,
    this.isEnabled = true,
    required this.relatedStretch,
    this.lastPerformedDate,
  });

  /// Check if exercise was performed yesterday (anti-repetition rule)
  bool wasPerformedYesterday() {
    if (lastPerformedDate == null) return false;

    final now = DateTime.now();
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final performedDate = DateTime(
      lastPerformedDate!.year,
      lastPerformedDate!.month,
      lastPerformedDate!.day,
    );

    return performedDate.isAtSameMomentAs(yesterday);
  }

  /// Check if exercise was performed today
  bool wasPerformedToday() {
    if (lastPerformedDate == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final performedDate = DateTime(
      lastPerformedDate!.year,
      lastPerformedDate!.month,
      lastPerformedDate!.day,
    );

    return performedDate.isAtSameMomentAs(today);
  }

  /// Create Exercise from JSON map
  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      type: ExerciseTypeExtension.fromJson(json['type'] as String),
      currentReps: json['currentReps'] as int,
      isTimed: json['isTimed'] as bool? ?? false,
      isBilateral: json['isBilateral'] as bool? ?? false,
      isEnabled: json['isEnabled'] as bool? ?? true,
      relatedStretch: json['relatedStretch'] as String,
      lastPerformedDate: json['lastPerformedDate'] != null
          ? DateTime.parse(json['lastPerformedDate'] as String)
          : null,
    );
  }

  /// Convert Exercise to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.toJson(),
      'currentReps': currentReps,
      'isTimed': isTimed,
      'isBilateral': isBilateral,
      'isEnabled': isEnabled,
      'relatedStretch': relatedStretch,
      'lastPerformedDate': lastPerformedDate?.toIso8601String(),
    };
  }

  /// Create a copy with updated fields
  Exercise copyWith({
    String? id,
    String? name,
    String? description,
    ExerciseType? type,
    int? currentReps,
    bool? isTimed,
    bool? isBilateral,
    bool? isEnabled,
    String? relatedStretch,
    DateTime? lastPerformedDate,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      currentReps: currentReps ?? this.currentReps,
      isTimed: isTimed ?? this.isTimed,
      isBilateral: isBilateral ?? this.isBilateral,
      isEnabled: isEnabled ?? this.isEnabled,
      relatedStretch: relatedStretch ?? this.relatedStretch,
      lastPerformedDate: lastPerformedDate ?? this.lastPerformedDate,
    );
  }

  @override
  String toString() {
    return 'Exercise(id: $id, name: $name, type: ${type.displayName}, '
        'currentReps: $currentReps, lastPerformed: $lastPerformedDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Exercise && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Seed data for initial exercises
class ExerciseData {
  /// Default starting rep count for new exercises
  static const int defaultStartingReps = 4;

  /// Default starting seconds for timed exercises
  static const int defaultStartingSeconds = 30;

  /// Get all seeded exercises with default values
  static List<Exercise> getSeedExercises() {
    return [
      // ===== LOWER BODY STRENGTH =====
      Exercise(
        id: 'deep_squat',
        name: 'Deep Squat (Paleo Chair)',
        description:
            'A resting squat held for time. Heels down, butt to ankles.',
        type: ExerciseType.strength,
        currentReps: defaultStartingSeconds,
        isTimed: true,
        relatedStretch:
            'Ankle Circles: Rotate each ankle 10 times in each direction.',
      ),
      Exercise(
        id: 'air_squat',
        name: 'Standard Air Squat',
        description: 'Basic knee/hip flexion. Keep chest high.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch:
            'Standing Quad Stretch: Pull foot to glutes, hold 30 seconds each side.',
      ),
      Exercise(
        id: 'reverse_lunge',
        name: 'Reverse Lunge',
        description:
            'Easier on the knees than forward lunges; opens the hip flexor of the trailing leg.',
        type: ExerciseType.strength,
        currentReps: 3, // Per leg
        isBilateral: true,
        relatedStretch:
            'Hip Flexor Stretch: Kneel on one knee, push hips forward. Hold 30 seconds each side.',
      ),
      Exercise(
        id: 'cossack_squat',
        name: 'Cossack Squat',
        description:
            'A side-to-side squat that deeply stretches the inner groin and trains lateral mobility.',
        type: ExerciseType.strength,
        currentReps: 3, // Per side
        isBilateral: true,
        relatedStretch:
            'Adductor Stretch: Wide stance, shift weight to one side, hold 30 seconds.',
      ),
      Exercise(
        id: 'bulgarian_split_squat',
        name: 'Bulgarian Split Squat',
        description:
            'Put your back foot on a couch or low wall (or just hover it). The "king" of leg builders.',
        type: ExerciseType.strength,
        currentReps: 3, // Per leg
        isBilateral: true,
        relatedStretch:
            'Pigeon Pose: Leg folded under body, lean forward to open hip.',
      ),
      Exercise(
        id: 'pistol_squat',
        name: 'Pistol Squat',
        description:
            'Single-leg squat. Modify by holding a doorframe or sitting to a chair.',
        type: ExerciseType.strength,
        currentReps: 2, // Per leg - challenging!
        isBilateral: true,
        relatedStretch:
            'Standing Hamstring Stretch: Foot on low surface, lean forward.',
      ),
      Exercise(
        id: 'calf_raises',
        name: 'Calf Raises',
        description: 'Standing on a flat floor or a stair step.',
        type: ExerciseType.strength,
        currentReps: 10,
        relatedStretch:
            'Wall Calf Stretch: Hands on wall, one leg back, heel down.',
      ),
      // ===== UPPER BODY PUSH =====
      Exercise(
        id: 'standard_pushup',
        name: 'Standard Push-Up',
        description: 'The classic. Targets chest and triceps.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch:
            'Doorway Chest Stretch: Arms on frame at 90°, lean forward, hold 30 seconds.',
      ),
      Exercise(
        id: 'diamond_pushup',
        name: 'Diamond Push-Up',
        description: 'Hands close together to target triceps.',
        type: ExerciseType.strength,
        currentReps: 3,
        relatedStretch: 'Tricep Stretch: Elbow overhead, push down gently.',
      ),
      Exercise(
        id: 'wide_grip_pushup',
        name: 'Wide Grip Push-Up',
        description: 'Hands wider than shoulders to target chest.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch:
            'Doorway Chest Stretch: Arms wide on frame, lean through.',
      ),
      Exercise(
        id: 'pike_pushup',
        name: 'Pike Push-Up',
        description:
            'Body in an upside-down V. Targets the shoulders (simulates a handstand push-up).',
        type: ExerciseType.strength,
        currentReps: 3,
        relatedStretch:
            'Shoulder Circles: Large circles forward and back, 10 each direction.',
      ),
      Exercise(
        id: 'hindu_pushup',
        name: 'Hindu Push-Up (Dive Bomber)',
        description:
            'Swooping from a Downward Dog into a Cobra pose. Works shoulders, chest, and spinal flexibility.',
        type: ExerciseType.strength,
        currentReps: 3,
        relatedStretch:
            'Cobra Pose: Lie on stomach, push chest up, hold 30 seconds.',
      ),
      Exercise(
        id: 'plank_to_pushup',
        name: 'Plank-to-Push-Up',
        description:
            'Starting in a forearm plank, pushing up to a hand plank, and back down.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch: 'Wrist Circles: Rotate wrists 10 times each direction.',
      ),

      // ===== UPPER BODY PULL & BACK =====
      Exercise(
        id: 'prone_cobra',
        name: 'Prone Cobra / Superman',
        description:
            'Lying on stomach, lifting chest and thighs off the ground. Essential for strengthening the lower back.',
        type: ExerciseType.strength,
        currentReps: 5, // Holds
        relatedStretch:
            'Child\'s Pose: Sit back on heels, arms extended, breathe deeply.',
      ),
      // ===== CORE & MIDLINE STABILITY =====
      Exercise(
        id: 'standard_plank',
        name: 'Standard Plank',
        description: 'Creating rigid tension from head to heel.',
        type: ExerciseType.strength,
        currentReps: defaultStartingSeconds,
        isTimed: true,
        relatedStretch: 'Cobra Pose: Lie on stomach, push chest up, breathe.',
      ),
      Exercise(
        id: 'side_plank',
        name: 'Side Plank',
        description: 'Targets the obliques and lateral hip stability.',
        type: ExerciseType.strength,
        currentReps: 20, // Seconds per side - starts lower
        isTimed: true,
        isBilateral: true,
        relatedStretch:
            'Side Lying Stretch: Reach arm overhead, elongate the side body.',
      ),
      Exercise(
        id: 'bird_dog',
        name: 'Bird Dog',
        description:
            'Kneeling, extending opposite arm and leg. Great for balance and back health.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps, // Per side
        isBilateral: true,
        relatedStretch: 'Cat-Cow: Arch and round the spine slowly, 5 cycles.',
      ),
      // ===== MOBILITY & RESTORATION =====
      Exercise(
        id: 'worlds_greatest_stretch',
        name: 'World\'s Greatest Stretch',
        description:
            'A deep lunge with a thoracic rotation (reaching hand to sky).',
        type: ExerciseType.mobility,
        currentReps: 3, // Per side
        isBilateral: true,
        relatedStretch:
            'Hold each position for 2-3 breaths before transitioning.',
      ),
      Exercise(
        id: 'pigeon_pose',
        name: 'Pigeon Pose',
        description: 'Leg folded under body to open the outer hip/glute.',
        type: ExerciseType.mobility,
        currentReps: defaultStartingSeconds, // Per side
        isTimed: true,
        isBilateral: true,
        relatedStretch:
            'Figure-4 Stretch: On back, ankle on knee, pull toward chest.',
      ),
      Exercise(
        id: '90_90_hip_stretch',
        name: '90/90 Hip Stretch',
        description:
            'Sitting with legs in 90-degree angles; switching knees side to side for hip internal/external rotation.',
        type: ExerciseType.mobility,
        currentReps: defaultStartingSeconds, // Per side
        isTimed: true,
        isBilateral: true,
        relatedStretch:
            'Butterfly Stretch: Soles together, knees out, lean forward.',
      ),
      Exercise(
        id: 'thoracic_bridge',
        name: 'Thoracic Bridge',
        description:
            'From a crab position, reaching one arm overhead and rotating to stretch the spine and belly.',
        type: ExerciseType.mobility,
        currentReps: 3, // Per side
        isBilateral: true,
        relatedStretch:
            'Thread the Needle: On all fours, reach arm under body and rotate.',
      ),
      Exercise(
        id: 'cat_cow',
        name: 'Cat-Cow',
        description:
            'On all fours, arching and rounding the spine with breath.',
        type: ExerciseType.mobility,
        currentReps: 5,
        relatedStretch:
            'Child\'s Pose: Sit back on heels, arms extended, breathe deeply.',
      ),
      Exercise(
        id: 'arm_circles',
        name: 'Arm Circles',
        description:
            'Large arm circles forward and backward to warm up shoulders.',
        type: ExerciseType.mobility,
        currentReps: 10, // Each direction
        relatedStretch:
            'Cross-Body Shoulder Stretch: Pull arm across chest, hold 20 seconds each.',
      ),

      // ===== ADDITIONAL CORE EXERCISES =====
      Exercise(
        id: 'flutter_kicks',
        name: 'Flutter Kicks',
        description:
            'Lying on back, legs straight, alternating small kicks up and down. Keep lower back pressed to floor.',
        type: ExerciseType.strength,
        currentReps: defaultStartingSeconds,
        isTimed: true,
        relatedStretch:
            'Knees to Chest: Hug both knees, rock gently side to side.',
      ),
      Exercise(
        id: 'hello_dollies',
        name: 'Hello Dollies',
        description:
            'Lying on back, legs straight up, spread legs apart then back together. Works inner thighs and core.',
        type: ExerciseType.strength,
        currentReps: 10,
        relatedStretch:
            'Butterfly Stretch: Soles together, knees out, lean forward.',
      ),
      Exercise(
        id: 'situps',
        name: 'Sit-Ups',
        description:
            'Classic core exercise. Lying on back, knees bent, curl up to touch knees with hands.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch:
            'Cobra Pose: Lie on stomach, push chest up, hold 30 seconds.',
      ),
      Exercise(
        id: 'crunches',
        name: 'Crunches',
        description:
            'Partial sit-up focusing on the upper abs. Lift shoulder blades off the ground.',
        type: ExerciseType.strength,
        currentReps: 10,
        relatedStretch: 'Knees to Chest: Hug both knees, rock gently.',
      ),

      // ===== ADDITIONAL UPPER BODY =====
      Exercise(
        id: 'dips',
        name: 'Dips',
        description:
            'Using a chair or low surface, lower body by bending elbows. Targets triceps and chest.',
        type: ExerciseType.strength,
        currentReps: defaultStartingReps,
        relatedStretch: 'Tricep Stretch: Elbow overhead, push down gently.',
      ),
      Exercise(
        id: 'pullups',
        name: 'Pull-Ups',
        description:
            'Hang from a bar, pull chin above the bar. The ultimate back and bicep builder. Use a doorway bar or playground.',
        type: ExerciseType.strength,
        currentReps: 2, // Challenging - start low
        relatedStretch:
            'Lat Stretch: Hang from bar with relaxed shoulders, or reach arm overhead and lean to side.',
      ),
    ];
  }
}
