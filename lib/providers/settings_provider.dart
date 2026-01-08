import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Provider for managing app settings state
class SettingsProvider extends ChangeNotifier {
  final StorageService _storageService;

  AppSettings _settings = AppSettings.defaults();
  bool _isLoading = true;

  SettingsProvider({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  // ============ GETTERS ============

  AppSettings get settings => _settings;
  bool get isLoading => _isLoading;

  /// Check if today is a sport day
  bool get isTodaySportDay => _settings.isTodaySportDay();

  /// Get today's exercise type description
  String get todayTypeDescription =>
      isTodaySportDay ? 'Sport Day (Mobility)' : 'Rest Day (Strength)';

  // ============ INITIALIZATION ============

  /// Initialize the provider by loading settings from storage
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    final storedSettings = await _storageService.loadSettings();

    if (storedSettings != null) {
      _settings = storedSettings;
    } else {
      // First launch - use defaults
      _settings = AppSettings.defaults();
      await _storageService.saveSettings(_settings);
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============ SPORT DAYS ============

  /// Toggle whether a specific day is a sport day
  Future<void> toggleSportDay(int weekday) async {
    final newSportDays = Map<int, bool>.from(_settings.sportDays);
    newSportDays[weekday] = !(newSportDays[weekday] ?? false);

    _settings = _settings.copyWith(sportDays: newSportDays);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Set a specific day as sport day or rest day
  Future<void> setSportDay(int weekday, bool isSportDay) async {
    final newSportDays = Map<int, bool>.from(_settings.sportDays);
    newSportDays[weekday] = isSportDay;

    _settings = _settings.copyWith(sportDays: newSportDays);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  // ============ ACTIVE WINDOW ============

  /// Set the active window start time
  Future<void> setActiveWindowStart(TimeOfDay time) async {
    _settings = _settings.copyWith(activeWindowStart: time);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Set the active window end time
  Future<void> setActiveWindowEnd(TimeOfDay time) async {
    _settings = _settings.copyWith(activeWindowEnd: time);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Set both active window times at once
  Future<void> setActiveWindow(TimeOfDay start, TimeOfDay end) async {
    _settings = _settings.copyWith(
      activeWindowStart: start,
      activeWindowEnd: end,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  // ============ NOTIFICATION SETTINGS ============

  /// Set number of exercise snacks per day
  Future<void> setSnacksPerDay(int count) async {
    if (count < 1) count = 1;
    if (count > 12) count = 12; // Reasonable maximum

    _settings = _settings.copyWith(snacksPerDay: count);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Toggle use imperial units
  Future<void> setUseImperialUnits(bool useImperial) async {
    _settings = _settings.copyWith(useImperialUnits: useImperial);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Toggle notifications enabled/disabled
  Future<void> toggleNotifications() async {
    _settings = _settings.copyWith(
      notificationsEnabled: !_settings.notificationsEnabled,
    );
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Set notifications enabled/disabled
  Future<void> setNotificationsEnabled(bool enabled) async {
    _settings = _settings.copyWith(notificationsEnabled: enabled);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  // ============ ONBOARDING ============

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    _settings = _settings.copyWith(hasSeenOnboarding: true);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  /// Reset onboarding (to show it again)
  Future<void> resetOnboarding() async {
    _settings = _settings.copyWith(hasSeenOnboarding: false);
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }

  // ============ RESET ============

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _settings = AppSettings.defaults();
    await _storageService.saveSettings(_settings);
    notifyListeners();
  }
}
