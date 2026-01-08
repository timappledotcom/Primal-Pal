import 'package:flutter/material.dart';

/// Model class for app settings including schedule and active window
class AppSettings {
  /// Map of weekday (1=Monday, 7=Sunday) to whether it's a Sport/HiT day
  /// true = Sport Day (Mobility exercises)
  /// false = Rest Day (Strength exercises)
  final Map<int, bool> sportDays;

  /// Start time of the active window for notifications
  final TimeOfDay activeWindowStart;

  /// End time of the active window for notifications
  final TimeOfDay activeWindowEnd;

  /// Number of exercise snacks to schedule per day
  final int snacksPerDay;

  /// Whether notifications are enabled
  final bool notificationsEnabled;

  /// Whether to use Imperial units (Miles) instead of Metric (Km)
  final bool useImperialUnits;

  /// Whether the user has seen the onboarding screen
  final bool hasSeenOnboarding;

  AppSettings({
    required this.sportDays,
    required this.activeWindowStart,
    required this.activeWindowEnd,
    this.snacksPerDay = 6,
    this.notificationsEnabled = true,
    this.useImperialUnits = false,
    this.hasSeenOnboarding = false,
  });

  /// Default settings with sensible initial values
  factory AppSettings.defaults() {
    return AppSettings(
      sportDays: {
        DateTime.monday: false,    // Rest Day
        DateTime.tuesday: true,    // Sport Day
        DateTime.wednesday: false, // Rest Day
        DateTime.thursday: true,   // Sport Day
        DateTime.friday: false,    // Rest Day
        DateTime.saturday: true,   // Sport Day
        DateTime.sunday: false,    // Rest Day
      },
      activeWindowStart: const TimeOfDay(hour: 7, minute: 0),
      activeWindowEnd: const TimeOfDay(hour: 20, minute: 0),
      snacksPerDay: 6,
      notificationsEnabled: true,
      useImperialUnits: false,
      hasSeenOnboarding: false,
    );
  }

  /// Check if today is a sport day
  bool isTodaySportDay() {
    final weekday = DateTime.now().weekday;
    return sportDays[weekday] ?? false;
  }

  /// Check if a specific day is a sport day
  bool isSportDay(int weekday) {
    return sportDays[weekday] ?? false;
  }

  /// Get display name for weekday
  static String getWeekdayName(int weekday) {
    const names = {
      DateTime.monday: 'Monday',
      DateTime.tuesday: 'Tuesday',
      DateTime.wednesday: 'Wednesday',
      DateTime.thursday: 'Thursday',
      DateTime.friday: 'Friday',
      DateTime.saturday: 'Saturday',
      DateTime.sunday: 'Sunday',
    };
    return names[weekday] ?? 'Unknown';
  }

  /// Get short display name for weekday
  static String getWeekdayShortName(int weekday) {
    const names = {
      DateTime.monday: 'Mon',
      DateTime.tuesday: 'Tue',
      DateTime.wednesday: 'Wed',
      DateTime.thursday: 'Thu',
      DateTime.friday: 'Fri',
      DateTime.saturday: 'Sat',
      DateTime.sunday: 'Sun',
    };
    return names[weekday] ?? '?';
  }

  /// Create from JSON
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Parse sport days map
    final sportDaysJson = json['sportDays'] as Map<String, dynamic>?;
    final sportDays = <int, bool>{};
    if (sportDaysJson != null) {
      sportDaysJson.forEach((key, value) {
        sportDays[int.parse(key)] = value as bool;
      });
    } else {
      // Default sport days if not present
      sportDays.addAll(AppSettings.defaults().sportDays);
    }

    return AppSettings(
      sportDays: sportDays,
      activeWindowStart: TimeOfDay(
        hour: json['activeWindowStartHour'] as int? ?? 7,
        minute: json['activeWindowStartMinute'] as int? ?? 0,
      ),
      activeWindowEnd: TimeOfDay(
        hour: json['activeWindowEndHour'] as int? ?? 20,
        minute: json['activeWindowEndMinute'] as int? ?? 0,
      ),
      snacksPerDay: json['snacksPerDay'] as int? ?? 6,
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      useImperialUnits: json['useImperialUnits'] as bool? ?? false,
      hasSeenOnboarding: json['hasSeenOnboarding'] as bool? ?? false,
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    // Convert sport days map to string keys for JSON
    final sportDaysJson = <String, bool>{};
    sportDays.forEach((key, value) {
      sportDaysJson[key.toString()] = value;
    });

    return {
      'sportDays': sportDaysJson,
      'activeWindowStartHour': activeWindowStart.hour,
      'activeWindowStartMinute': activeWindowStart.minute,
      'activeWindowEndHour': activeWindowEnd.hour,
      'activeWindowEndMinute': activeWindowEnd.minute,
      'snacksPerDay': snacksPerDay,
      'notificationsEnabled': notificationsEnabled,
      'useImperialUnits': useImperialUnits,
      'hasSeenOnboarding': hasSeenOnboarding,
    };
  }

  /// Create copy with updated fields
  AppSettings copyWith({
    Map<int, bool>? sportDays,
    TimeOfDay? activeWindowStart,
    TimeOfDay? activeWindowEnd,
    int? snacksPerDay,
    bool? notificationsEnabled,
    bool? useImperialUnits,
    bool? hasSeenOnboarding,
  }) {
    return AppSettings(
      sportDays: sportDays ?? Map.from(this.sportDays),
      activeWindowStart: activeWindowStart ?? this.activeWindowStart,
      activeWindowEnd: activeWindowEnd ?? this.activeWindowEnd,
      snacksPerDay: snacksPerDay ?? this.snacksPerDay,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      useImperialUnits: useImperialUnits ?? this.useImperialUnits,
      hasSeenOnboarding: hasSeenOnboarding ?? this.hasSeenOnboarding,
    );
  }

  /// Get active window duration in minutes
  int get activeWindowDurationMinutes {
    final startMinutes = activeWindowStart.hour * 60 + activeWindowStart.minute;
    final endMinutes = activeWindowEnd.hour * 60 + activeWindowEnd.minute;
    return endMinutes - startMinutes;
  }

  /// Format TimeOfDay for display
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
  
  /// Check if the given time is within the active window
  bool isInActiveWindow(TimeOfDay time) {
    final nowMinutes = time.hour * 60 + time.minute;
    final startMinutes = activeWindowStart.hour * 60 + activeWindowStart.minute;
    final endMinutes = activeWindowEnd.hour * 60 + activeWindowEnd.minute;
    
    // Handle case where window spans midnight (though not typical for this app)
    if (endMinutes < startMinutes) {
       return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
    }
    
    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  @override
  String toString() {
    return 'AppSettings(sportDays: $sportDays, '
        'activeWindow: ${formatTimeOfDay(activeWindowStart)} - '
        '${formatTimeOfDay(activeWindowEnd)}, '
        'snacksPerDay: $snacksPerDay, '
        'notificationsEnabled: $notificationsEnabled)';
  }
}
