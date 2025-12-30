import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for managing exercises state and business logic
class ExerciseProvider extends ChangeNotifier {
  final StorageService _storageService;

  List<Exercise> _exercises = [];
  Exercise? _currentExercise;
  bool _isLoading = true;

  ExerciseProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  // ============ GETTERS ============

  List<Exercise> get exercises => List.unmodifiable(_exercises);
  Exercise? get currentExercise => _currentExercise;
  bool get isLoading => _isLoading;

  /// Get all strength exercises
  List<Exercise> get strengthExercises =>
      _exercises.where((e) => e.type == ExerciseType.strength).toList();

  /// Get all mobility exercises
  List<Exercise> get mobilityExercises =>
      _exercises.where((e) => e.type == ExerciseType.mobility).toList();

  // ============ INITIALIZATION ============

  /// Initialize the provider by loading exercises from storage
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    // Try to load exercises from storage
    final storedExercises = await _storageService.loadExercises();

    if (storedExercises != null && storedExercises.isNotEmpty) {
      _exercises = storedExercises;

      // Check for new exercises in seed data and add them
      final seedExercises = ExerciseData.getSeedExercises();
      final existingIds = _exercises.map((e) => e.id).toSet();

      final newExercises =
          seedExercises.where((e) => !existingIds.contains(e.id)).toList();

      if (newExercises.isNotEmpty) {
        _exercises.addAll(newExercises);
        await _storageService.saveExercises(_exercises);
      }
    } else {
      // First launch - use seed data
      _exercises = ExerciseData.getSeedExercises();
      await _storageService.saveExercises(_exercises);
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============ FILTERING LOGIC ============

  /// Get exercises available for today based on settings
  ///
  /// Rules:
  /// - Sport Day (true) → Mobility exercises only
  /// - Rest Day (false) → Strength exercises only
  /// - Anti-Repetition: Exclude exercises performed yesterday
  /// - Only include enabled exercises
  List<Exercise> getAvailableExercisesForToday(AppSettings settings) {
    final isSportDay = settings.isTodaySportDay();

    // Filter by day type
    final typeFilter =
        isSportDay ? ExerciseType.mobility : ExerciseType.strength;

    return _exercises
        .where((exercise) => exercise.isEnabled)
        .where((exercise) => exercise.type == typeFilter)
        .where((exercise) => !exercise.wasPerformedYesterday())
        .toList();
  }

  /// Get exercises for a specific day type (for testing/preview)
  List<Exercise> getExercisesForDayType({required bool isSportDay}) {
    final typeFilter =
        isSportDay ? ExerciseType.mobility : ExerciseType.strength;

    return _exercises
        .where((exercise) => exercise.isEnabled)
        .where((exercise) => exercise.type == typeFilter)
        .where((exercise) => !exercise.wasPerformedYesterday())
        .toList();
  }

  /// Select a random exercise from available exercises for today
  Exercise? selectRandomExercise(AppSettings settings) {
    final available = getAvailableExercisesForToday(settings);

    if (available.isEmpty) {
      // Fallback: if all exercises were performed yesterday,
      // return any enabled exercise of the correct type
      final isSportDay = settings.isTodaySportDay();
      final typeFilter =
          isSportDay ? ExerciseType.mobility : ExerciseType.strength;
      final fallback =
          _exercises.where((e) => e.isEnabled && e.type == typeFilter).toList();

      if (fallback.isEmpty) return null;

      return fallback[DateTime.now().millisecond % fallback.length];
    }

    // Pick random from available
    return available[DateTime.now().millisecond % available.length];
  }

  // ============ EXERCISE MANAGEMENT ============

  /// Set the current exercise (when notification is tapped)
  void setCurrentExercise(String exerciseId) {
    _currentExercise = _exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => _exercises.first,
    );
    notifyListeners();
  }

  /// Set current exercise directly
  void setCurrentExerciseObject(Exercise exercise) {
    _currentExercise = exercise;
    notifyListeners();
  }

  /// Clear the current exercise
  void clearCurrentExercise() {
    _currentExercise = null;
    notifyListeners();
  }

  /// Get exercise by ID
  Exercise? getExerciseById(String id) {
    try {
      return _exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Toggle exercise enabled state
  Future<void> toggleExerciseEnabled(String exerciseId) async {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;

    _exercises[index].isEnabled = !_exercises[index].isEnabled;
    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  /// Set exercise enabled state
  Future<void> setExerciseEnabled(String exerciseId, bool enabled) async {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;

    _exercises[index].isEnabled = enabled;
    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  // ============ SESSION COMPLETION & PROGRESSION ============

  /// Complete an exercise session with progression logic
  ///
  /// Progression Algorithm:
  /// - If user clicks "Yes (Easy)" AND completes target reps:
  /// - If user clicks "Yes (Easy)" AND completes target:
  ///   - For rep exercises: +2 reps
  ///   - For timed exercises: +5 seconds
  ///
  /// Returns the updated exercise
  Future<Exercise> completeSession({
    required String exerciseId,
    required int actualRepsPerformed,
    required bool wasEasy,
  }) async {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) {
      throw Exception('Exercise not found: $exerciseId');
    }

    final exercise = _exercises[index];
    final targetReps = exercise.currentReps;

    // Calculate new value based on progression algorithm
    int newValue = exercise.currentReps;

    if (wasEasy && actualRepsPerformed >= targetReps) {
      // Progression: +5 seconds for timed, +2 reps for regular
      newValue = exercise.currentReps + (exercise.isTimed ? 5 : 2);
    }

    // Update exercise with new values
    final updatedExercise = exercise.copyWith(
      currentReps: newValue,
      lastPerformedDate: DateTime.now(),
    );

    // Update in list
    _exercises[index] = updatedExercise;

    // Persist to storage
    await _storageService.saveExercises(_exercises);

    // Clear current exercise
    _currentExercise = null;

    notifyListeners();

    return updatedExercise;
  }

  /// Mark exercise as performed today (without progression)
  Future<void> markAsPerformed(String exerciseId) async {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;

    final exercise = _exercises[index];
    _exercises[index] = exercise.copyWith(
      lastPerformedDate: DateTime.now(),
    );

    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  /// Manually adjust rep count for an exercise
  Future<void> adjustReps(String exerciseId, int newReps) async {
    if (newReps < 1) newReps = 1; // Minimum 1 rep

    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index == -1) return;

    final exercise = _exercises[index];
    _exercises[index] = exercise.copyWith(currentReps: newReps);

    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  // ============ DATA MANAGEMENT ============

  /// Reset "last performed" dates for exercises of today's type
  /// This allows re-shuffling/re-picking exercises for today
  Future<void> resetTodaysExercises(AppSettings settings) async {
    final isSportDay = settings.isTodaySportDay();
    final typeFilter =
        isSportDay ? ExerciseType.mobility : ExerciseType.strength;

    for (int i = 0; i < _exercises.length; i++) {
      if (_exercises[i].type == typeFilter) {
        // Clear lastPerformedDate to make it available again
        _exercises[i] = _exercises[i].copyWith(
          lastPerformedDate: null,
        );
      }
    }

    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  /// Reset all exercises to seed data
  Future<void> resetToDefaults() async {
    _exercises = ExerciseData.getSeedExercises();
    await _storageService.saveExercises(_exercises);
    _currentExercise = null;
    notifyListeners();
  }

  /// Add a custom exercise
  Future<void> addExercise(Exercise exercise) async {
    _exercises.add(exercise);
    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }

  /// Remove an exercise
  Future<void> removeExercise(String exerciseId) async {
    _exercises.removeWhere((e) => e.id == exerciseId);
    await _storageService.saveExercises(_exercises);
    notifyListeners();
  }
}
