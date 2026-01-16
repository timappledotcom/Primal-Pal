import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/models.dart';

/// Service for managing local notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Callback for when notification is tapped
  static Function(String? exerciseId)? onNotificationTapped;

  /// Callback for snooze action
  static Function(String? exerciseId, int minutes)? onSnoozeTapped;

  /// Initialize the notification service
  Future<void> init() async {
    if (_initialized) return;

    // Initialize timezone
    tz_data.initializeTimeZones();

    // Android initialization settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization settings for all platforms
    const initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _initialized = true;
  }

  /// Handle notification tap
  static void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    // Handle snooze actions
    if (actionId != null && actionId.startsWith('snooze_') && payload != null) {
      final minutes = int.tryParse(actionId.replaceFirst('snooze_', '')) ?? 30;
      if (onSnoozeTapped != null) {
        onSnoozeTapped!(payload, minutes);
      }
      return;
    }

    // Handle regular notification tap
    if (payload != null && onNotificationTapped != null) {
      onNotificationTapped!(payload);
    }
  }

  /// Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  /// Schedule all daily exercise notifications at random times within active window
  /// This should be called once per day (on app launch or via WorkManager)
  /// Returns a list of ScheduledExercise objects for display purposes
  Future<List<ScheduledExercise>> scheduleDailyNotifications({
    required List<Exercise> availableExercises,
    required AppSettings settings,
  }) async {
    if (!settings.notificationsEnabled) return [];
    if (availableExercises.isEmpty) return [];

    // Cancel existing notifications first
    await cancelAllNotifications();

    final now = DateTime.now();
    final random = Random();

    // Calculate active window bounds for today
    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
      settings.activeWindowStart.hour,
      settings.activeWindowStart.minute,
    );

    final windowEnd = DateTime(
      now.year,
      now.month,
      now.day,
      settings.activeWindowEnd.hour,
      settings.activeWindowEnd.minute,
    );

    // Calculate midpoint and split counts
    final totalDuration = windowEnd.difference(windowStart);
    // If window is invalid (end before start), do nothing
    if (totalDuration.isNegative) return [];

    final midpoint =
        windowStart.add(Duration(minutes: totalDuration.inMinutes ~/ 2));

    // Add a small buffer around midpoint so they don't overlap too closely
    // Only apply buffer if we have enough time (at least 2 hours)
    final bufferMinutes = totalDuration.inHours >= 2 ? 15 : 0;

    final morningEnd = midpoint.subtract(Duration(minutes: bufferMinutes));
    final afternoonStart = midpoint.add(Duration(minutes: bufferMinutes));

    // Split the snacks count: half in morning, half in afternoon
    // If odd, morning gets one more
    final morningCount = (settings.snacksPerDay / 2).ceil();
    final afternoonCount = settings.snacksPerDay - morningCount;

    final scheduleTimes = <DateTime>[];

    // Generate random times for morning
    if (morningCount > 0) {
      scheduleTimes.addAll(_generateRandomTimes(
        windowStart: windowStart,
        windowEnd: morningEnd,
        count: morningCount,
        random: random,
      ));
    }

    // Generate random times for afternoon
    if (afternoonCount > 0) {
      scheduleTimes.addAll(_generateRandomTimes(
        windowStart: afternoonStart,
        windowEnd: windowEnd,
        count: afternoonCount,
        random: random,
      ));
    }

    // Filter out times that have already passed
    final futureTimes =
        scheduleTimes.where((time) => time.isAfter(now)).toList();

    // Create a shuffled list of exercises to use (avoids repeats when possible)
    final exercisesToSchedule = _selectExercisesForDay(
      availableExercises: availableExercises,
      count: futureTimes.length,
      random: random,
    );

    // List to store scheduled exercises for return
    final scheduledExercises = <ScheduledExercise>[];

    // Schedule notifications at each time
    for (var i = 0; i < futureTimes.length; i++) {
      final exercise = exercisesToSchedule[i];

      await _scheduleNotification(
        id: i,
        exercise: exercise,
        scheduledTime: futureTimes[i],
      );

      // Create ScheduledExercise for tracking
      scheduledExercises.add(ScheduledExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        scheduledTime: futureTimes[i],
        notificationId: i,
      ));
    }

    debugPrint('Scheduled ${futureTimes.length} notifications for today');
    return scheduledExercises;
  }

  /// Select exercises for the day, avoiding repeats when possible
  /// If count > available, exercises will repeat but be evenly distributed
  List<Exercise> _selectExercisesForDay({
    required List<Exercise> availableExercises,
    required int count,
    required Random random,
  }) {
    if (availableExercises.isEmpty) return [];

    final result = <Exercise>[];

    // Shuffle the available exercises to randomize order
    final shuffled = List<Exercise>.from(availableExercises)..shuffle(random);

    // Fill the result list, cycling through shuffled exercises if needed
    for (var i = 0; i < count; i++) {
      result.add(shuffled[i % shuffled.length]);
    }

    // Shuffle again so the order isn't predictable
    result.shuffle(random);

    return result;
  }

  /// Generate random times within the active window
  List<DateTime> _generateRandomTimes({
    required DateTime windowStart,
    required DateTime windowEnd,
    required int count,
    required Random random,
  }) {
    final times = <DateTime>[];
    final windowDurationMinutes = windowEnd.difference(windowStart).inMinutes;

    // Minimum gap between notifications (in minutes)
    const minGap = 30;

    if (windowDurationMinutes < minGap * count) {
      // Window too small for all notifications, distribute evenly
      final interval = windowDurationMinutes ~/ count;
      for (var i = 0; i < count; i++) {
        times.add(
            windowStart.add(Duration(minutes: interval * i + interval ~/ 2)));
      }
    } else {
      // Generate random times with minimum gap
      for (var i = 0; i < count; i++) {
        DateTime newTime;
        var attempts = 0;
        const maxAttempts = 100;

        do {
          final randomMinutes = random.nextInt(windowDurationMinutes);
          newTime = windowStart.add(Duration(minutes: randomMinutes));
          attempts++;
        } while (_isTooCloseToExisting(newTime, times, minGap) &&
            attempts < maxAttempts);

        times.add(newTime);
      }
    }

    // Sort times chronologically
    times.sort();
    return times;
  }

  /// Check if a time is too close to existing scheduled times
  bool _isTooCloseToExisting(
      DateTime time, List<DateTime> existing, int minGapMinutes) {
    for (final existingTime in existing) {
      final diff = time.difference(existingTime).inMinutes.abs();
      if (diff < minGapMinutes) {
        return true;
      }
    }
    return false;
  }

  /// Schedule a single notification
  Future<void> _scheduleNotification({
    required int id,
    required Exercise exercise,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'exercise_snacks',
      'Exercise Snacks',
      channelDescription: 'Notifications for exercise snack reminders',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Exercise time!',
      icon: '@mipmap/ic_launcher',
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'snooze_30',
          '⏰ 30 min',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'snooze_60',
          '⏰ 60 min',
          showsUserInterface: false,
        ),
        const AndroidNotificationAction(
          'snooze_90',
          '⏰ 90 min',
          showsUserInterface: false,
        ),
      ],
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // Create notification body with exercise info
    final body =
        '${exercise.currentReps} reps • ${exercise.relatedStretch.split('.').first}';

    await _notifications.zonedSchedule(
      id,
      '🏋️ ${exercise.name}',
      body,
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: exercise.id,
    );

    debugPrint('Scheduled: ${exercise.name} at $scheduledTime');
  }

  /// Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  /// Show an immediate test notification
  Future<void> showTestNotification(Exercise exercise) async {
    final androidDetails = AndroidNotificationDetails(
      'exercise_snacks',
      'Exercise Snacks',
      channelDescription: 'Notifications for exercise snack reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.show(
      999,
      '🏋️ ${exercise.name}',
      '${exercise.currentReps} reps • Tap to start!',
      notificationDetails,
      payload: exercise.id,
    );
  }

  /// Get pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notifications.pendingNotificationRequests();
  }

  /// Snooze a notification by rescheduling it
  Future<ScheduledExercise?> snoozeNotification({
    required ScheduledExercise scheduled,
    required Exercise exercise,
    required int snoozeMinutes,
  }) async {
    // Cancel the original notification
    await cancelNotification(scheduled.notificationId);

    // Calculate new time
    final newTime = DateTime.now().add(Duration(minutes: snoozeMinutes));

    // Schedule new notification
    await _scheduleNotification(
      id: scheduled.notificationId + 100, // Offset ID to avoid conflicts
      exercise: exercise,
      scheduledTime: newTime,
    );

    // Return updated scheduled exercise
    return scheduled.snooze(snoozeMinutes);
  }

  // ============ SPRINT NOTIFICATIONS ============

  /// Schedule a sprint notification for today (if sprint day)
  Future<void> scheduleSprintNotification(SprintSession sprint) async {
    if (!sprint.isToday || sprint.completed) return;

    final androidDetails = AndroidNotificationDetails(
      'sprint_sessions',
      'Sprint Sessions',
      channelDescription: 'Notifications for sprint session reminders',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Sprint day!',
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    // Schedule for 9 AM on sprint day
    final now = DateTime.now();
    var scheduledTime = DateTime(now.year, now.month, now.day, 9, 0);

    // If it's already past 9 AM, show immediately
    if (now.isAfter(scheduledTime)) {
      await _notifications.show(
        900, // Sprint notification ID
        '🏃 Sprint Day!',
        'Today is your sprint session. Get ready to run!',
        notificationDetails,
        payload: 'sprint_${sprint.date.toIso8601String()}',
      );
    } else {
      await _notifications.zonedSchedule(
        900,
        '🏃 Sprint Day!',
        'Today is your sprint session. Get ready to run!',
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'sprint_${sprint.date.toIso8601String()}',
      );
    }

    debugPrint('Scheduled sprint notification for today');
  }

  /// Cancel sprint notification
  Future<void> cancelSprintNotification() async {
    await _notifications.cancel(900);
  }
}
