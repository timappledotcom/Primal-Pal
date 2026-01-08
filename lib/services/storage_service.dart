import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Service for persisting app data using SharedPreferences
class StorageService {
  static const String _exercisesKey = 'exercises';
  static const String _settingsKey = 'app_settings';
  static const String _lastScheduledDateKey = 'last_scheduled_date';
  static const String _scheduledExercisesKey = 'scheduled_exercises';
  static const String _exerciseHistoryKey = 'exercise_history';
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

  // ============ EXERCISE HISTORY ============

  /// Log a completed exercise to history
  Future<void> logExerciseCompletion(ScheduledExercise exercise) async {
    final p = await prefs;
    final history = await loadExerciseHistory();
    
    final entry = ExerciseHistoryEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      exerciseId: exercise.exerciseId,
      exerciseName: exercise.exerciseName,
      completedAt: DateTime.now(),
    );
    
    history.add(entry);
    
    final jsonList = history.map((e) => e.toJson()).toList();
    await p.setString(_exerciseHistoryKey, jsonEncode(jsonList));
  }
  
  /// Load exercise history
  Future<List<ExerciseHistoryEntry>> loadExerciseHistory() async {
    final p = await prefs;
    final jsonString = p.getString(_exerciseHistoryKey);
    
    if (jsonString == null) {
      return [];
    }
    
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => ExerciseHistoryEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading exercise history: $e');
      return [];
    }
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
    double? distanceMeters,
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
      distanceMeters: distanceMeters ?? 0,
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
  Future<DailyWalk> addSecondsToTodaysWalk(int seconds, {double extraDistance = 0}) async {
    final walks = await loadDailyWalks();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final existingIndex =
        walks.indexWhere((w) => w.dateOnly.isAtSameMomentAs(today));

    DailyWalk updatedWalk;
    if (existingIndex != -1) {
      updatedWalk = walks[existingIndex].addSeconds(seconds, extraDistance: extraDistance);
      walks[existingIndex] = updatedWalk;
    } else {
      updatedWalk = DailyWalk(date: today, totalSeconds: seconds, distanceMeters: extraDistance);
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
      final newDays =
          SprintScheduler.generateSprintDaysForMonth(now.year, now.month);
      for (final day in newDays) {
        // Only add if not already scheduled
        final exists = sprints.any((s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day);
        if (!exists) {
          final random = Random(day.millisecondsSinceEpoch);
          final sets = 3 + random.nextInt(4); // 3 to 6
          sprints.add(SprintSession(date: day, targetSets: sets));
          updated = true;
        }
      }
    }

    // Check next month
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    if (SprintScheduler.needsSchedulingForMonth(
        sprints, nextMonth.year, nextMonth.month)) {
      final newDays = SprintScheduler.generateSprintDaysForMonth(
          nextMonth.year, nextMonth.month);
      for (final day in newDays) {
        final exists = sprints.any((s) =>
            s.date.year == day.year &&
            s.date.month == day.month &&
            s.date.day == day.day);
        if (!exists) {
          final random = Random(day.millisecondsSinceEpoch);
          final sets = 3 + random.nextInt(4); // 3 to 6
          sprints.add(SprintSession(date: day, targetSets: sets));
          updated = true;
        }
      }
    }

    if (updated) {
      await saveSprintSessions(sprints);
    }

    return sprints;
  }
  
  /// Reschedule incomplete sprints for the current month
  Future<void> rescheduleSprintsForMonth() async {
    final sprints = await loadSprintSessions();
    final now = DateTime.now();
    
    // Remove only INCOMPLETE sprints for the current month
    sprints.removeWhere((s) => 
      s.date.year == now.year && 
      s.date.month == now.month && 
      !s.completed
    );
    
    // Now force regeneration.
    // However, ensureSprintsScheduled only runs if NO sprints exist for the month.
    // We need to manually generate missing slots.
    
    // Count existing (completed) sprints for this month
    final completedCount = sprints.where((s) => 
      s.date.year == now.year && 
      s.date.month == now.month
    ).length;
    
    final toSchedule = 2 - completedCount; // Assuming 2 per month
    
    if (toSchedule > 0) {
       // Use randomize=true to get a fresh set of days
       final newDays = SprintScheduler.generateSprintDaysForMonth(now.year, now.month, randomize: true);
       
       // Filter out days that might conflict with existing completed ones?
       // Or just take the ones from 'newDays' that are in the future?
       
       int added = 0;
       for (final day in newDays) {
         if (added >= toSchedule) break;
         
         // Only add if date is in future (or today) AND doesn't conflict with existing completed
         // Actually, if we just blindly add from newDays, we might duplicate.
         
         final exists = sprints.any((s) => 
            s.date.year == day.year && 
            s.date.month == day.month && 
            s.date.day == day.day);
            
         if (!exists && !day.isBefore(DateTime(now.year, now.month, now.day))) {
            final random = Random(day.millisecondsSinceEpoch);
            final sets = 3 + random.nextInt(4);
            sprints.add(SprintSession(date: day, targetSets: sets));
            added++;
         }
       }
       
       // Fallback: if 'newDays' didn't give us valid future dates (e.g. late in month),
       // pick random future days effectively.
       if (added < toSchedule) {
          final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
          final remainingDays = daysInMonth - now.day;
          
          if (remainingDays > 0) {
             final random = Random();
             for (int i = 0; i < (toSchedule - added); i++) {
                final dayOffset = random.nextInt(remainingDays) + 1; // 1 to remaining
                final d = DateTime(now.year, now.month, now.day + dayOffset);
                
                 final exists = sprints.any((s) => 
                    s.date.year == d.year && 
                    s.date.month == d.month && 
                    s.date.day == d.day);
                 
                 if (!exists) {
                    final r = Random(d.millisecondsSinceEpoch);
                    final sets = 3 + r.nextInt(4);
                    sprints.add(SprintSession(date: d, targetSets: sets));
                 }
             }
          }
       }
    }
    
    // Re-sort
    sprints.sort((a,b) => a.date.compareTo(b.date));
    await saveSprintSessions(sprints);
  }
  
  /// Update a sprint session (e.g. tracking progress)
  Future<void> updateSprintSession(SprintSession updatedSession) async {
    final sprints = await loadSprintSessions();
    final index = sprints.indexWhere((s) => 
        s.date.year == updatedSession.date.year && 
        s.date.month == updatedSession.date.month && 
        s.date.day == updatedSession.date.day);
        
    if (index != -1) {
      sprints[index] = updatedSession;
      await saveSprintSessions(sprints);
    }
  }

  /// Add a manual/ad-hoc sprint session
  Future<void> addAdHocSprint(DateTime date, int targetSets) async {
    final sprints = await loadSprintSessions();
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    // Check if one already exists
    final index = sprints.indexWhere((s) => 
        s.date.year == dateOnly.year && 
        s.date.month == dateOnly.month && 
        s.date.day == dateOnly.day);
        
    final newSession = SprintSession(
      date: dateOnly,
      targetSets: targetSets,
    );
        
    if (index != -1) {
      // Replace existing (user explicitly asked for this)
      sprints[index] = newSession;
    } else {
      sprints.add(newSession);
    }
    
    sprints.sort((a,b) => a.date.compareTo(b.date));
    await saveSprintSessions(sprints);
  }

  /// Get today's sprint session if scheduled
  /// Also ensures target reps are generated if it's sprint day
  Future<SprintSession?> getTodaysSprint() async {
    final sprints = await loadSprintSessions();
    final session = SprintScheduler.getTodaysSprint(sprints);
    
    if (session != null && session.targetSets == null && !session.completed) {
      // Generate random target sets (3-6)
      final random = Random();
      final target = 3 + random.nextInt(4); // 3, 4, 5, 6
      
      final index = sprints.indexWhere((s) => s.date == session.date);
      if (index != -1) {
        final updated = session.copyWith(targetSets: target);
        sprints[index] = updated;
        await saveSprintSessions(sprints);
        return updated;
      }
    }
    
    return session;
  }

  /// Increment completed reps for today's sprint
  Future<SprintSession?> incrementSprintRep() async {
    final sprints = await loadSprintSessions();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final index = sprints.indexWhere((s) => s.dateOnly.isAtSameMomentAs(today));
    if (index == -1) return null;

    final session = sprints[index];
    final currentReps = session.completedSets;
    
    // Don't increment if already completed everything (unless we want extra credit?)
    // User requirement: "So if that day you were supposed to run 4, you would have run the timer 4 times."
    // Let's allow incrementing but maybe check completion status.
    
    final updated = session.copyWith(
      completedSets: currentReps + 1,
    );
    
    sprints[index] = updated;
    await saveSprintSessions(sprints);
    
    // Auto-complete if reached target?
    // "Then everytime the timer slected runs out, it would count one of the reps."
    // It doesn't explicitly say "auto mark complete", but implies the session is done when reps are done.
    // I'll leave manual completion or check in UI. UIs usually handle "You're done!" logic.
    
    return updated;
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
