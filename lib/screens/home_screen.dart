import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import 'active_session_screen.dart';
import 'settings_screen.dart';
import 'walk_history_screen.dart';
import 'sprint_history_screen.dart';

/// Home screen displaying today's schedule and exercise overview
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _exercisePoolExpanded = false;
  List<ScheduledExercise> _scheduledExercises = [];
  final StorageService _storageService = StorageService();

  // Walk timer state
  int _todayTotalSeconds = 0;
  int _currentStreak = 0;
  bool _isWalkTimerRunning = false;
  Timer? _walkTimer;
  DateTime? _walkStartTime;

  // Sprint state
  SprintSession? _todaysSprint;
  SprintSession? _nextSprint;

  @override
  void initState() {
    super.initState();
    _loadScheduledExercises();
    _loadTodaysWalk();
    _loadSprintData();
    _scheduleNotificationsIfNeeded();
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSprintData() async {
    // Ensure sprints are scheduled for current and next month
    await _storageService.ensureSprintsScheduled();
    
    final todaysSprint = await _storageService.getTodaysSprint();
    final upcomingSprints = await _storageService.getUpcomingSprints();
    
    // Find next sprint (could be today if not completed, or a future one)
    SprintSession? nextSprint;
    if (upcomingSprints.isNotEmpty) {
      nextSprint = upcomingSprints.firstWhere(
        (s) => !s.completed,
        orElse: () => upcomingSprints.first,
      );
    }

    // Schedule notification if today is sprint day
    if (todaysSprint != null && !todaysSprint.completed) {
      await NotificationService().scheduleSprintNotification(todaysSprint);
    }

    if (mounted) {
      setState(() {
        _todaysSprint = todaysSprint;
        _nextSprint = nextSprint;
      });
    }
  }

  Future<void> _completeSprint() async {
    final completed = await _storageService.completeTodaysSprint();
    if (completed != null) {
      await NotificationService().cancelSprintNotification();
      await _loadSprintData();
    }
  }

  Future<void> _loadTodaysWalk() async {
    final todaysWalk = await _storageService.getTodaysWalk();
    final walks = await _storageService.loadDailyWalks();
    final stats = WalkStatistics.fromWalks(walks);

    if (mounted) {
      setState(() {
        _todayTotalSeconds = todaysWalk?.totalSeconds ?? 0;
        _currentStreak = stats.currentStreak;
      });
    }
  }

  void _toggleWalkTimer() {
    if (_isWalkTimerRunning) {
      _stopWalkTimer();
    } else {
      _startWalkTimer();
    }
  }

  void _startWalkTimer() {
    setState(() {
      _isWalkTimerRunning = true;
      _walkStartTime = DateTime.now();
    });

    _walkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _todayTotalSeconds++;
        });
      }
    });
  }

  Future<void> _stopWalkTimer() async {
    _walkTimer?.cancel();
    _walkTimer = null;

    if (_walkStartTime != null) {
      final elapsed = DateTime.now().difference(_walkStartTime!).inSeconds;
      await _storageService.addSecondsToTodaysWalk(elapsed);
    }

    if (mounted) {
      setState(() {
        _isWalkTimerRunning = false;
        _walkStartTime = null;
      });
      // Reload to sync with stored value and update streak
      await _loadTodaysWalk();
    }
  }

  String _formatWalkTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _loadScheduledExercises() async {
    final scheduled = await _storageService.loadScheduledExercises();
    if (scheduled != null && mounted) {
      setState(() {
        _scheduledExercises = scheduled;
      });
    }
  }

  Future<void> _scheduleNotificationsIfNeeded() async {
    final storageService = StorageService();
    final needsScheduling = await storageService.needsSchedulingToday();

    if (needsScheduling && mounted) {
      final exerciseProvider = context.read<ExerciseProvider>();
      final settingsProvider = context.read<SettingsProvider>();

      final availableExercises = exerciseProvider
          .getAvailableExercisesForToday(settingsProvider.settings);

      final scheduled = await NotificationService().scheduleDailyNotifications(
        availableExercises: availableExercises,
        settings: settingsProvider.settings,
      );

      // Save scheduled exercises for display
      await storageService.saveScheduledExercises(scheduled);

      if (mounted) {
        setState(() {
          _scheduledExercises = scheduled;
        });
      }

      await storageService.saveLastScheduledDate(DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Swole Timer'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Consumer2<ExerciseProvider, SettingsProvider>(
        builder: (context, exerciseProvider, settingsProvider, _) {
          if (exerciseProvider.isLoading || settingsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: _scheduleNotificationsIfNeeded,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTodayCard(settingsProvider),
                const SizedBox(height: 16),
                _buildDailyWalkCard(),
                const SizedBox(height: 16),
                _buildSprintCard(),
                const SizedBox(height: 16),
                _buildActiveWindowCard(settingsProvider),
                const SizedBox(height: 16),
                _buildQuickStartButton(exerciseProvider, settingsProvider),
                const SizedBox(height: 16),
                _buildTodaysExercisesCard(exerciseProvider, settingsProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayCard(SettingsProvider settingsProvider) {
    final isSportDay = settingsProvider.isTodaySportDay;
    final dayName = AppSettings.getWeekdayName(DateTime.now().weekday);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              dayName,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSportDay
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isSportDay ? Icons.sports_gymnastics : Icons.fitness_center,
                    color: isSportDay ? Colors.orange : Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isSportDay ? 'Sport Day' : 'Rest Day',
                    style: TextStyle(
                      color: isSportDay ? Colors.orange : Colors.blue,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSportDay
                  ? 'Focus on Mobility exercises'
                  : 'Focus on Strength exercises',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyWalkCard() {
    final hasWalkedToday = _todayTotalSeconds > 0;

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const WalkHistoryScreen()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _isWalkTimerRunning
                          ? Colors.green.withOpacity(0.2)
                          : hasWalkedToday
                              ? Colors.blue.withOpacity(0.2)
                              : Colors.grey.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_walk,
                      color: _isWalkTimerRunning
                          ? Colors.green
                          : hasWalkedToday
                              ? Colors.blue
                              : Colors.grey,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Walk',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          _isWalkTimerRunning ? 'Timer running...' : 'Tap to see history',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: _isWalkTimerRunning ? Colors.green : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 16),
              // Timer display
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  _formatWalkTime(_todayTotalSeconds),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: _isWalkTimerRunning ? Colors.green : null,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              // Start/Stop button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _toggleWalkTimer,
                  icon: Icon(
                    _isWalkTimerRunning ? Icons.stop : Icons.play_arrow,
                  ),
                  label: Text(_isWalkTimerRunning ? 'Stop Walk' : 'Start Walk'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWalkTimerRunning ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              if (_currentStreak > 0) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department,
                        color: Colors.amber,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$_currentStreak day streak!',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSprintCard() {
    final isSprintDay = _todaysSprint != null;
    final isCompleted = _todaysSprint?.completed ?? false;

    String _formatSprintDate(DateTime date) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly.isAtSameMomentAs(today)) {
        return 'Today';
      } else if (dateOnly.isAtSameMomentAs(tomorrow)) {
        return 'Tomorrow';
      }

      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      final daysUntil = dateOnly.difference(today).inDays;
      
      if (daysUntil <= 7) {
        return '${weekdays[date.weekday - 1]} (in $daysUntil days)';
      }
      return '${months[date.month - 1]} ${date.day}';
    }

    return Card(
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SprintHistoryScreen()),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSprintDay
                          ? (isCompleted
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2))
                          : Colors.purple.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.directions_run,
                      color: isSprintDay
                          ? (isCompleted ? Colors.green : Colors.orange)
                          : Colors.purple,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sprint Session',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          isSprintDay
                              ? (isCompleted ? 'Completed!' : 'Today is sprint day!')
                              : _nextSprint != null
                                  ? 'Next: ${_formatSprintDate(_nextSprint!.date)}'
                                  : '2x per month',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: isSprintDay && !isCompleted
                                    ? Colors.orange
                                    : Colors.grey[600],
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              if (isSprintDay && !isCompleted) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _completeSprint,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark Complete'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
              if (isSprintDay && isCompleted) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Sprint complete!',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWindowCard(SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Active Window',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppSettings.formatTimeOfDay(settings.activeWindowStart),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(Icons.arrow_forward),
                ),
                Text(
                  AppSettings.formatTimeOfDay(settings.activeWindowEnd),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                '${settings.snacksPerDay} exercise snacks scheduled',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysExercisesCard(
    ExerciseProvider exerciseProvider,
    SettingsProvider settingsProvider,
  ) {
    final exercises = exerciseProvider
        .getAvailableExercisesForToday(settingsProvider.settings);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Collapsible header
          InkWell(
            onTap: () {
              setState(() {
                _exercisePoolExpanded = !_exercisePoolExpanded;
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Today\'s Schedule',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_scheduledExercises.length}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _exercisePoolExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              ),
            ),
          ),
          // Collapsible content
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: [
                  if (_scheduledExercises.isEmpty && exercises.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'All exercises were performed yesterday.\nThey\'ll be available tomorrow!',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else if (_scheduledExercises.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No scheduled alerts yet.\nPull to refresh to schedule.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    )
                  else
                    ..._scheduledExercises.map((scheduled) {
                      final exercise = exerciseProvider
                          .getExerciseById(scheduled.exerciseId);
                      if (exercise != null) {
                        return _buildScheduledExerciseTile(scheduled, exercise);
                      }
                      return const SizedBox.shrink();
                    }),
                ],
              ),
            ),
            crossFadeState: _exercisePoolExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduledExerciseTile(
      ScheduledExercise scheduled, Exercise exercise) {
    final isPast = scheduled.isPast;
    final isUpcoming = scheduled.isUpcoming;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: isPast
            ? Colors.grey.withOpacity(0.2)
            : exercise.type == ExerciseType.strength
                ? Colors.blue.withOpacity(0.2)
                : Colors.orange.withOpacity(0.2),
        child: Icon(
          exercise.type == ExerciseType.strength
              ? Icons.fitness_center
              : Icons.self_improvement,
          color: isPast
              ? Colors.grey
              : exercise.type == ExerciseType.strength
                  ? Colors.blue
                  : Colors.orange,
          size: 20,
        ),
      ),
      title: Text(
        exercise.name,
        style: TextStyle(
          color: isPast ? Colors.grey : null,
          decoration: isPast ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            exercise.isTimed
                ? '${exercise.currentReps} seconds'
                : '${exercise.currentReps} reps',
            style: TextStyle(
              color: isPast ? Colors.grey : null,
            ),
          ),
          if (scheduled.isSnoozed) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Snoozed',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPast
              ? Colors.grey.withOpacity(0.1)
              : isUpcoming
                  ? Colors.green.withOpacity(0.2)
                  : Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPast ? Icons.check : Icons.access_time,
              size: 14,
              color: isPast
                  ? Colors.grey
                  : isUpcoming
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 4),
            Text(
              scheduled.formattedTime,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPast
                    ? Colors.grey
                    : isUpcoming
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
      onTap: () => _startSession(exercise),
      onLongPress: isPast ? null : () => _showSnoozeDialog(scheduled, exercise),
    );
  }

  Future<void> _showSnoozeDialog(
      ScheduledExercise scheduled, Exercise exercise) async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Snooze Alert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reschedule "${exercise.name}" alert?'),
            const SizedBox(height: 8),
            Text(
              'Currently scheduled for ${scheduled.formattedTime}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 30),
            child: const Text('30 min'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 60),
            child: const Text('60 min'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 90),
            child: const Text('90 min'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await _snoozeExercise(scheduled, exercise, result);
    }
  }

  Future<void> _snoozeExercise(
    ScheduledExercise scheduled,
    Exercise exercise,
    int minutes,
  ) async {
    final snoozed = await NotificationService().snoozeNotification(
      scheduled: scheduled,
      exercise: exercise,
      snoozeMinutes: minutes,
    );

    if (snoozed != null) {
      // Update local state
      setState(() {
        final index = _scheduledExercises.indexWhere(
          (s) => s.notificationId == scheduled.notificationId,
        );
        if (index != -1) {
          _scheduledExercises[index] = snoozed;
          // Re-sort by time
          _scheduledExercises
              .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
        }
      });

      // Save to storage
      await _storageService.saveScheduledExercises(_scheduledExercises);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${exercise.name} snoozed for $minutes minutes'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildQuickStartButton(
    ExerciseProvider exerciseProvider,
    SettingsProvider settingsProvider,
  ) {
    return ElevatedButton.icon(
      onPressed: () {
        final exercise =
            exerciseProvider.selectRandomExercise(settingsProvider.settings);
        if (exercise != null) {
          _startSession(exercise);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No exercises available for today!'),
            ),
          );
        }
      },
      icon: const Icon(Icons.play_arrow),
      label: const Text('Quick Start Random Exercise'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        minimumSize: const Size(double.infinity, 56),
      ),
    );
  }

  void _startSession(Exercise exercise) {
    context.read<ExerciseProvider>().setCurrentExerciseObject(exercise);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
    );
  }
}
