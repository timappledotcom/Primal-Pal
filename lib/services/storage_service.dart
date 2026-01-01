import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for persisting app data using SharedPreferences
class StorageService {
  static const String _exercisesKey = 'exercises';
  static const String _settingsKey = 'app_settings';
  static const String _lastScheduledDateKey = 'last_scheduled_date';
  static const String _scheduledExercisesKey = 'scheduled_exercises';
  static const String _dailyWalksKey = 'daily_walks';
  static const String _sprintSessionsKey = 'sprint_sessions';

  SharedPreferences? _prefs;

  /// Initialize the storage service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Ensure prefs are initialized
  Future<SharedPreferences> get prefs async {
    if (_prefs == null) {
      await init();
    }
    return _prefs!;
  }

  // ============ EXERCISES ============

  /// Save exercises list to storage
  Future<void> saveExercises(List<Exercise> exercises) async {
    final p = await prefs;
    final jsonList = exercises.map((e) => e.toJson()).toList();
    await p.setString(_exercisesKey, jsonEncode(jsonList));
  }

  /// Load exercises from storage
  /// Returns null if no exercises are stored (first launch)
  Future<List<Exercise>?> loadExercises() async {
    final p = await prefs;
    final jsonString = p.getString(_exercisesKey);

    if (jsonString == null) {
      return null;
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => Exercise.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // If parsing fails, return null to trigger seed data
      print('Error loading exercises: $e');
      return null;
    }
  }

  /// Update a single exercise in storage
  Future<void> updateExercise(Exercise updatedExercise) async {
    final exercises = await loadExercises();
    if (exercises == null) return;

    final index = exercises.indexWhere((e) => e.id == updatedExercise.id);
    if (index != -1) {
      exercises[index] = updatedExercise;
      await saveExercises(exercises);
    }
  }

  // ============ SETTINGS ============

  /// Save app settings to storage
  Future<void> saveSettings(AppSettings settings) async {
    final p = await prefs;
    await p.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  /// Load app settings from storage
  /// Returns null if no settings are stored (first launch)
  Future<AppSettings?> loadSettings() async {
    final p = await prefs;
    final jsonString = p.getString(_settingsKey);

    if (jsonString == null) {
      return null;
    }

    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (e) {
      print('Error loading settings: $e');
      return null;
    }
  }

  // ============ SCHEDULING ============

  /// Save the date when notifications were last scheduled
  Future<void> saveLastScheduledDate(DateTime date) async {
    final p = await prefs;
    await p.setString(_lastScheduledDateKey, date.toIso8601String());
  }

  /// Get the date when notifications were last scheduled
  Future<DateTime?> getLastScheduledDate() async {
    final p = await prefs;
    final dateString = p.getString(_lastScheduledDateKey);

    if (dateString == null) {
      return null;
    }

    try {
      return DateTime.parse(dateString);
    } catch (e) {
      return null;
    }
  }

  /// Check if notifications need to be scheduled today
  Future<bool> needsSchedulingToday() async {
    final lastScheduled = await getLastScheduledDate();
    if (lastScheduled == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastScheduledDay = DateTime(
      lastScheduled.year,
      lastScheduled.month,
      lastScheduled.day,
    );

    return !today.isAtSameMomentAs(lastScheduledDay);
  }

  // ============ UTILITY ============

  /// Clear all stored data (for testing/reset)
  Future<void> clearAll() async {
    final p = await prefs;
    await p.clear();
  }

  // ============ SCHEDULED EXERCISES ============

  /// Save scheduled exercises for today
  Future<void> saveScheduledExercises(List<ScheduledExercise> scheduled) async {
    final p = await prefs;
    final jsonList = scheduled.map((e) => e.toJson()).toList();
    await p.setString(_scheduledExercisesKey, jsonEncode(jsonList));
  }

  /// Load scheduled exercises
  Future<List<ScheduledExercise>?> loadScheduledExercises() async {
    final p = await prefs;
    final jsonString = p.getString(_scheduledExercisesKey);

    if (jsonString == null) {
      return null;
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) =>
              ScheduledExercise.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading scheduled exercises: $e');
      return null;
    }
  }

  /// Update a single scheduled exercise (e.g., after snooze)
  Future<void> updateScheduledExercise(ScheduledExercise updated) async {
    final scheduled = await loadScheduledExercises();
    if (scheduled == null) return;

    final index =
        scheduled.indexWhere((e) => e.notificationId == updated.notificationId);
    if (index != -1) {
      scheduled[index] = updated;
      await saveScheduledExercises(scheduled);
    }
  }

  /// Clear scheduled exercises
  Future<void> clearScheduledExercises() async {
    final p = await prefs;
    await p.remove(_scheduledExercisesKey);
  }

  // ============ DAILY WALKS ============

  /// Save all daily walks
  Future<void> saveDailyWalks(List<DailyWalk> walks) async {
    final p = await prefs;
    final jsonList = walks.map((e) => e.toJson()).toList();
    await p.setString(_dailyWalksKey, jsonEncode(jsonList));
  }

  /// Load all daily walks
  Future<List<DailyWalk>> loadDailyWalks() async {
    final p = await prefs;
    final jsonString = p.getString(_dailyWalksKey);

    if (jsonString == null) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => DailyWalk.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading daily walks: $e');
      return [];
    }
  }

  /// Get today's walk (if logged)
  Future<DailyWalk?> getTodaysWalk() async {
    final walks = await loadDailyWalks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    try {
      return walks.firstWhere((w) => w.dateOnly.isAtSameMomentAs(today));
    } catch (_) {
      return null;
    }
  }

  /// Log or update today's walk with accumulated time
  Future<void> logTodaysWalk({
    int? totalSeconds,
    String? notes,
  }) async {
    final walks = await loadDailyWalks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingIndex =
        walks.indexWhere((w) => w.dateOnly.isAtSameMomentAs(today));

    final newWalk = DailyWalk(
      date: today,
      totalSeconds: totalSeconds ?? 0,
      notes: notes,
    );

    if (existingIndex != -1) {
      walks[existingIndex] = newWalk;
    } else {
      walks.add(newWalk);
    }

    await saveDailyWalks(walks);
  }

  /// Add seconds to today's walk timer
  Future<DailyWalk> addSecondsToTodaysWalk(int seconds) async {
    final walks = await loadDailyWalks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingIndex =
        walks.indexWhere((w) => w.dateOnly.isAtSameMomentAs(today));

    DailyWalk updatedWalk;
    if (existingIndex != -1) {
      updatedWalk = walks[existingIndex].addSeconds(seconds);
      walks[existingIndex] = updatedWalk;
    } else {
      updatedWalk = DailyWalk(date: today, totalSeconds: seconds);
      walks.add(updatedWalk);
    }

    await saveDailyWalks(walks);
    return updatedWalk;
  }

  /// Get walks for a date range
  Future<List<DailyWalk>> getWalksInRange(DateTime start, DateTime end) async {
    final walks = await loadDailyWalks();
    final startDate = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    return walks.where((w) {
      return !w.dateOnly.isBefore(startDate) && !w.dateOnly.isAfter(endDate);
    }).toList();
  }

  /// Get walks for the current week (Monday to Sunday)
  Future<List<DailyWalk>> getThisWeeksWalks() async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return getWalksInRange(monday, sunday);
  }

  /// Get walks for the current month
  Future<List<DailyWalk>> getThisMonthsWalks() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    return getWalksInRange(firstDay, lastDay);
  }

  /// Get walks for the current year
  Future<List<DailyWalk>> getThisYearsWalks() async {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, 1, 1);
    final lastDay = DateTime(now.year, 12, 31);
    return getWalksInRange(firstDay, lastDay);
  }

  // ============ SPRINT SESSIONS ============

  /// Save all sprint sessions
  Future<void> saveSprintSessions(List<SprintSession> sprints) async {
    final p = await prefs;
    final jsonList = sprints.map((e) => e.toJson()).toList();
    await p.setString(_sprintSessionsKey, jsonEncode(jsonList));
  }

  /// Load all sprint sessions
  Future<List<SprintSession>> loadSprintSessions() async {
    final p = await prefs;
    final jsonString = p.getString(_sprintSessionsKey);

    if (jsonString == null) {
      return [];
    }

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => SprintSession.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading sprint sessions: $e');
      return [];
    }
  }

  /// Ensure sprints are scheduled for the current month and next month
  /// Returns the updated list of all sprints
  Future<List<SprintSession>> ensureSprintsScheduled() async {
    final sprints = await loadSprintSessions();
    final now = DateTime.now();
    var updated = false;

    // Check current month
    if (SprintScheduler.needsSchedulingForMonth(sprints, now.year, now.month)) {
      final newDays = SprintScheduler.generateSprintDaysForMonth(now.year, now.month);
      for (final day in newDays) {
        // Only add if not already scheduled
        final exists = sprints.any((s) => 
          s.date.year == day.year && 
          s.date.month == day.month && 
          s.date.day == day.day
        );
        if (!exists) {
          sprints.add(SprintSession(date: day));
          updated = true;
        }
      }
    }

    // Check next month
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    if (SprintScheduler.needsSchedulingForMonth(sprints, nextMonth.year, nextMonth.month)) {
      final newDays = SprintScheduler.generateSprintDaysForMonth(nextMonth.year, nextMonth.month);
      for (final day in newDays) {
        final exists = sprints.any((s) => 
          s.date.year == day.year && 
          s.date.month == day.month && 
          s.date.day == day.day
        );
        if (!exists) {
          sprints.add(SprintSession(date: day));
          updated = true;
        }
      }
    }

    if (updated) {
      await saveSprintSessions(sprints);
    }

    return sprints;
  }

  /// Get today's sprint session if scheduled
  Future<SprintSession?> getTodaysSprint() async {
    final sprints = await loadSprintSessions();
    return SprintScheduler.getTodaysSprint(sprints);
  }

  /// Mark today's sprint as completed
  Future<SprintSession?> completeTodaysSprint() async {
    final sprints = await loadSprintSessions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final index = sprints.indexWhere((s) => s.dateOnly.isAtSameMomentAs(today));
    if (index == -1) return null;

    final completed = sprints[index].markCompleted();
    sprints[index] = completed;
    await saveSprintSessions(sprints);

    return completed;
  }

  /// Get upcoming sprints (including today)
  Future<List<SprintSession>> getUpcomingSprints() async {
    final sprints = await loadSprintSessions();
    return SprintScheduler.getUpcomingSprints(sprints);
  }

  /// Get past sprints for history
  Future<List<SprintSession>> getPastSprints() async {
    final sprints = await loadSprintSessions();
    return SprintScheduler.getPastSprints(sprints);
  }

  /// Get sprint statistics
  Future<SprintStatistics> getSprintStatistics() async {
    final sprints = await loadSprintSessions();
    return SprintStatistics.fromSprints(sprints);
  }
}
