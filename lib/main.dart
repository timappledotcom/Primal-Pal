import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/models.dart';
import 'providers/providers.dart';
import 'services/services.dart';
import 'screens/screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storageService = StorageService();
  await storageService.init();

  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  runApp(
    PrimalPalApp(storageService: storageService),
  );
}

class PrimalPalApp extends StatefulWidget {
  final StorageService storageService;

  const PrimalPalApp({
    super.key,
    required this.storageService,
  });

  @override
  State<PrimalPalApp> createState() => _PrimalPalAppState();
}

class _PrimalPalAppState extends State<PrimalPalApp> {
  late final ExerciseProvider _exerciseProvider;
  late final SettingsProvider _settingsProvider;

  @override
  void initState() {
    super.initState();
    _exerciseProvider = ExerciseProvider(storageService: widget.storageService);
    _settingsProvider = SettingsProvider(storageService: widget.storageService);

    // Set up notification tap handler
    NotificationService.onNotificationTapped = _handleNotificationTap;

    // Set up snooze handler
    NotificationService.onSnoozeTapped = _handleSnoozeTap;

    // Initialize providers
    _initializeProviders();
  }

  Future<void> _initializeProviders() async {
    await Future.wait([
      _exerciseProvider.init(),
      _settingsProvider.init(),
    ]);

    // Check and schedule daily exercises if needed
    await _checkDailySchedule();
  }
  
  Future<void> _checkDailySchedule() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Load existing scheduled exercises
    final existingSchedule = await widget.storageService.loadScheduledExercises();
    
    // Check if we need to schedule (list is empty, or first item is not from today)
    bool needsScheduling = false;
    
    if (existingSchedule == null || existingSchedule.isEmpty) {
      needsScheduling = true;
    } else {
      final firstScheduled = existingSchedule.first;
      final scheduledDate = DateTime(
        firstScheduled.scheduledTime.year,
        firstScheduled.scheduledTime.month,
        firstScheduled.scheduledTime.day,
      );
      
      if (!scheduledDate.isAtSameMomentAs(today)) {
        needsScheduling = true;
      }
    }
    
    if (needsScheduling && mounted) {
      final availableExercises = _exerciseProvider.getAvailableExercisesForToday(_settingsProvider.settings);
      
      final newSchedule = await NotificationService().scheduleDailyNotifications(
        availableExercises: availableExercises, 
        settings: _settingsProvider.settings
      );
      
      await widget.storageService.saveScheduledExercises(newSchedule);
      debugPrint('Daily schedule updated with ${newSchedule.length} exercises.');
    }
  }

  void _handleNotificationTap(String? exerciseId) async {
    if (exerciseId != null) {
      // Load scheduled exercises to find the matching one
      final scheduled = await widget.storageService.loadScheduledExercises();
      ScheduledExercise? matchingScheduled;
      
      if (scheduled != null) {
        try {
          matchingScheduled = scheduled.firstWhere(
            (s) => s.exerciseId == exerciseId && !s.isCompleted,
          );
        } catch (_) {
          // No matching scheduled exercise found, that's okay
        }
      }
      
      // Get the exercise and set it with the scheduled exercise context
      final exercise = _exerciseProvider.getExerciseById(exerciseId);
      if (exercise != null) {
        _exerciseProvider.setCurrentExerciseObject(
          exercise, 
          scheduledExercise: matchingScheduled,
        );
      } else {
        // Fallback: just set by ID
        _exerciseProvider.setCurrentExercise(exerciseId);
      }
      
      // Navigation will be handled by the navigator key
      _navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => const ActiveSessionScreen(),
        ),
      );
    }
  }

  Future<void> _handleSnoozeTap(String? exerciseId, int minutes) async {
    if (exerciseId == null) return;

    final exercise = _exerciseProvider.getExerciseById(exerciseId);
    if (exercise == null) return;

    // Load current scheduled exercises
    final scheduled = await widget.storageService.loadScheduledExercises();
    if (scheduled == null) return;

    // Find the matching scheduled exercise
    final scheduledExercise = scheduled.firstWhere(
      (s) => s.exerciseId == exerciseId,
      orElse: () => ScheduledExercise(
        exerciseId: exerciseId,
        exerciseName: exercise.name,
        scheduledTime: DateTime.now(),
        notificationId: 0,
      ),
    );

    // Snooze the notification
    final snoozed = await NotificationService().snoozeNotification(
      scheduled: scheduledExercise,
      exercise: exercise,
      snoozeMinutes: minutes,
    );

    if (snoozed != null) {
      // Update in storage
      final index = scheduled.indexWhere((s) => s.exerciseId == exerciseId);
      if (index != -1) {
        scheduled[index] = snoozed;
        scheduled.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        await widget.storageService.saveScheduledExercises(scheduled);
      }

      debugPrint('Snoozed ${exercise.name} for $minutes minutes');
    }
  }

  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _exerciseProvider),
        ChangeNotifierProvider.value(value: _settingsProvider),
      ],
      child: MaterialApp(
        title: 'Primal Pal',
        navigatorKey: _navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepOrange,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          cardTheme: CardThemeData(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        themeMode: ThemeMode.system,
        home: Consumer<SettingsProvider>(
          builder: (context, settingsProvider, _) {
            if (settingsProvider.isLoading) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!settingsProvider.settings.hasSeenOnboarding) {
              return OnboardingScreen(
                onComplete: () {
                  settingsProvider.completeOnboarding();
                },
              );
            }

            return const HomeScreen();
          },
        ),
      ),
    );
  }
}
