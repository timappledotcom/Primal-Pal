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

  /// Schedule daily session notifications and create exercise list
  /// This schedules 2 reminders (morning & afternoon) and assigns exercises to sessions
  Future<List<ScheduledExercise>> scheduleDailyNotifications({
    required List<Exercise> availableExercises,
    required AppSettings settings,
  }) async {
    if (availableExercises.isEmpty) return [];

    // Cancel existing notifications first
    await cancelAllNotifications();

    final now = DateTime.now();
    final random = Random();

    // Split the snacks count: half in morning, half in afternoon
    // If odd, morning gets one more
    final morningCount = (settings.snacksPerDay / 2).ceil();
    final afternoonCount = settings.snacksPerDay - morningCount;

    // Create a shuffled list of exercises
    final shuffled = List<Exercise>.from(availableExercises)..shuffle(random);

    // List to store scheduled exercises for return
    final scheduledExercises = <ScheduledExercise>[];

    // Assign exercises to morning session
    for (var i = 0; i < morningCount; i++) {
      final exercise = shuffled[i % shuffled.length];
      scheduledExercises.add(ScheduledExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        scheduledTime: DateTime(
          now.year,
          now.month,
          now.day,
          settings.morningReminderTime.hour,
          settings.morningReminderTime.minute,
        ),
        notificationId: i,
        session: 'morning',
      ));
    }

    // Assign exercises to afternoon session
    for (var i = 0; i < afternoonCount; i++) {
      final exercise = shuffled[(morningCount + i) % shuffled.length];
      scheduledExercises.add(ScheduledExercise(
        exerciseId: exercise.id,
        exerciseName: exercise.name,
        scheduledTime: DateTime(
          now.year,
          now.month,
          now.day,
          settings.afternoonReminderTime.hour,
          settings.afternoonReminderTime.minute,
        ),
        notificationId: morningCount + i,
        session: 'afternoon',
      ));
    }

    // Schedule session reminder notifications if enabled
    if (settings.notificationsEnabled) {
      final morningReminderTime = DateTime(
        now.year,
        now.month,
        now.day,
        settings.morningReminderTime.hour,
        settings.morningReminderTime.minute,
      );

      final afternoonReminderTime = DateTime(
        now.year,
        now.month,
        now.day,
        settings.afternoonReminderTime.hour,
        settings.afternoonReminderTime.minute,
      );

      // Schedule morning reminder if it's in the future
      if (morningReminderTime.isAfter(now)) {
        await _scheduleSessionReminder(
          id: 100,
          session: 'Morning',
          exerciseCount: morningCount,
          scheduledTime: morningReminderTime,
        );
      }

      // Schedule afternoon reminder if it's in the future
      if (afternoonReminderTime.isAfter(now)) {
        await _scheduleSessionReminder(
          id: 101,
          session: 'Afternoon',
          exerciseCount: afternoonCount,
          scheduledTime: afternoonReminderTime,
        );
      }
    }

    debugPrint(
        'Scheduled $morningCount morning + $afternoonCount afternoon exercises');
    return scheduledExercises;
  }

  /// Schedule a session reminder notification
  Future<void> _scheduleSessionReminder({
    required int id,
    required String session,
    required int exerciseCount,
    required DateTime scheduledTime,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'exercise_sessions',
      'Exercise Sessions',
      channelDescription: 'Reminders for exercise sessions',
      importance: Importance.high,
      priority: Priority.high,
      ticker: 'Exercise time!',
      icon: '@mipmap/ic_launcher',
    );

    final notificationDetails = NotificationDetails(android: androidDetails);

    await _notifications.zonedSchedule(
      id,
      '🏋️ $session Session',
      '$exerciseCount exercises ready to go!',
      tz.TZDateTime.from(scheduledTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'session_$session',
    );

    debugPrint('Scheduled $session session reminder at $scheduledTime');
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
