import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import 'active_session_screen.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  final StorageService _storageService = StorageService();
  List<ScheduledExercise> _scheduledExercises = [];
  bool _isLoading = true;
  bool _morningExpanded = true;
  bool _afternoonExpanded = true;

  @override
  void initState() {
    super.initState();
    _loadScheduledExercises();
  }

  Future<void> _loadScheduledExercises() async {
    setState(() => _isLoading = true);
    var scheduled = await _storageService.loadScheduledExercises();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool needsReschedule = false;

    // Check for stale data or missing session field
    if (scheduled == null || scheduled.isEmpty) {
      needsReschedule = true;
    } else {
      final firstTime = scheduled.first.scheduledTime;
      final firstDate =
          DateTime(firstTime.year, firstTime.month, firstTime.day);
      if (!firstDate.isAtSameMomentAs(today)) {
        needsReschedule = true;
      }
      // Check if sessions are properly assigned (not all in one session)
      final hasMorning = scheduled.any((e) => e.session == 'morning');
      final hasAfternoon = scheduled.any((e) => e.session == 'afternoon');
      if (!hasMorning || !hasAfternoon) {
        // Old data without proper session assignment
        needsReschedule = true;
      }
    }

    if (needsReschedule && mounted) {
      final settingsProvider = context.read<SettingsProvider>();
      final exerciseProvider = context.read<ExerciseProvider>();
      final available = exerciseProvider
          .getAvailableExercisesForToday(settingsProvider.settings);

      if (available.isNotEmpty) {
        scheduled = await NotificationService().scheduleDailyNotifications(
          availableExercises: available,
          settings: settingsProvider.settings,
        );
        await _storageService.saveScheduledExercises(scheduled);
      } else {
        scheduled = [];
      }
    }

    // Reconciliation: Check history for completions that missed the schedule update
    if (scheduled != null && scheduled.isNotEmpty) {
      final history = await _storageService.loadExerciseHistory();
      final exerciseList = scheduled; // Non-null assertion for the block

      final todaysHistory = history.where((h) {
        final hDate = DateTime(
            h.completedAt.year, h.completedAt.month, h.completedAt.day);
        return hDate.isAtSameMomentAs(today);
      }).toList();

      bool changed = false;
      for (int i = 0; i < exerciseList.length; i++) {
        if (!exerciseList[i].isCompleted) {
          // Check if we have a history entry for this exercise ID
          final hasCompletion = todaysHistory
              .any((h) => h.exerciseId == exerciseList[i].exerciseId);
          if (hasCompletion) {
            exerciseList[i] = exerciseList[i].markCompleted();
            changed = true;
          }
        }
      }

      if (changed) {
        await _storageService.saveScheduledExercises(exerciseList);
      }
      scheduled = exerciseList;
    }

    if (mounted) {
      setState(() {
        _scheduledExercises = scheduled ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshExercises() async {
    // Force reschedule if needed, or just reload?
    // Re-using logic from HomeScreen.
    // Logic: If needed, schedule. If already scheduled, just load.
    // For now, let's just reload from storage.
    await _loadScheduledExercises();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Today\'s Exercises'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshExercises,
            tooltip: 'Reload exercises',
          ),
          IconButton(
            icon: const Icon(Icons.shuffle),
            onPressed: _repickExercises,
            tooltip: 'Repick exercises',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _scheduledExercises.isEmpty
              ? const Center(child: Text('No exercises scheduled for today.'))
              : _buildGroupedList(context),
    );
  }

  Future<void> _repickExercises() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Repick Exercises?'),
        content: const Text(
          'This will randomly select new exercises for today. Your current progress will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Repick'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final settingsProvider = context.read<SettingsProvider>();
      final exerciseProvider = context.read<ExerciseProvider>();

      // Get available exercises for today
      final available = exerciseProvider
          .getAvailableExercisesForToday(settingsProvider.settings);

      if (available.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No exercises available to schedule'),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Reschedule with new random selection
      final newScheduled =
          await NotificationService().scheduleDailyNotifications(
        availableExercises: available,
        settings: settingsProvider.settings,
      );

      await _storageService.saveScheduledExercises(newScheduled);

      if (mounted) {
        setState(() {
          _scheduledExercises = newScheduled;
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exercises repicked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error repicking exercises: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildGroupedList(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;

    // Group by session field
    final morningExercises =
        _scheduledExercises.where((e) => e.session == 'morning').toList();

    final afternoonExercises =
        _scheduledExercises.where((e) => e.session == 'afternoon').toList();

    // Check completion status for each session
    final morningComplete = morningExercises.isNotEmpty &&
        morningExercises.every((e) => e.isCompleted);
    final afternoonComplete = afternoonExercises.isNotEmpty &&
        afternoonExercises.every((e) => e.isCompleted);

    // Count completed exercises
    final morningCompletedCount =
        morningExercises.where((e) => e.isCompleted).length;
    final afternoonCompletedCount =
        afternoonExercises.where((e) => e.isCompleted).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (morningExercises.isNotEmpty) ...[
          _buildCollapsibleSection(
            context,
            title: 'Morning Session',
            reminderTime: settings.morningReminderTime,
            isComplete: morningComplete,
            completedCount: morningCompletedCount,
            totalCount: morningExercises.length,
            isExpanded: _morningExpanded,
            onToggle: () =>
                setState(() => _morningExpanded = !_morningExpanded),
            isMorning: true,
          ),
          if (_morningExpanded)
            ...morningExercises.map((e) => _buildExerciseCard(context, e)),
          const SizedBox(height: 16),
        ],
        if (afternoonExercises.isNotEmpty) ...[
          _buildCollapsibleSection(
            context,
            title: 'Afternoon Session',
            reminderTime: settings.afternoonReminderTime,
            isComplete: afternoonComplete,
            completedCount: afternoonCompletedCount,
            totalCount: afternoonExercises.length,
            isExpanded: _afternoonExpanded,
            onToggle: () =>
                setState(() => _afternoonExpanded = !_afternoonExpanded),
            isMorning: false,
          ),
          if (_afternoonExpanded)
            ...afternoonExercises.map((e) => _buildExerciseCard(context, e)),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildCollapsibleSection(
    BuildContext context, {
    required String title,
    required TimeOfDay reminderTime,
    required bool isComplete,
    required int completedCount,
    required int totalCount,
    required bool isExpanded,
    required VoidCallback onToggle,
    required bool isMorning,
  }) {
    final baseColor =
        isComplete ? Colors.green : (isMorning ? Colors.orange : Colors.blue);

    return GestureDetector(
      onTap: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(
              isComplete
                  ? Icons.check_circle
                  : (isMorning ? Icons.wb_sunny : Icons.nights_stay),
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    isComplete
                        ? 'All $totalCount completed! ✓'
                        : '$completedCount/$totalCount done • Reminder ${reminderTime.format(context)}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isExpanded ? Icons.expand_less : Icons.expand_more,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, ScheduledExercise scheduled) {
    final isCompleted = scheduled.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCompleted
              ? Colors.green.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          child: Icon(
            isCompleted ? Icons.check : Icons.fitness_center,
            color: isCompleted ? Colors.green : Colors.blue,
          ),
        ),
        title: Text(
          scheduled.exerciseName,
          style: TextStyle(
            decoration: isCompleted ? TextDecoration.lineThrough : null,
            color: isCompleted ? Colors.grey : null,
          ),
        ),
        trailing: isCompleted
            ? const Icon(Icons.check_circle, color: Colors.green)
            : IconButton(
                icon: const Icon(Icons.check_circle_outline),
                onPressed: () => _onExerciseTap(context, scheduled),
              ),
        onTap: () => _onExerciseTap(context, scheduled),
      ),
    );
  }

  void _onExerciseTap(BuildContext context, ScheduledExercise scheduled) {
    final provider = context.read<ExerciseProvider>();
    try {
      // Use getExerciseById if available, otherwise find manually
      // Assuming getExerciseById might not be on the provider if I didn't see it,
      // but I'll trust the previous code used it.
      // Safe fallback:
      final exercise =
          provider.exercises.firstWhere((e) => e.id == scheduled.exerciseId);

      provider.setCurrentExerciseObject(exercise, scheduledExercise: scheduled);
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
      ).then((_) => _refreshExercises());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise not found')),
      );
    }
  }
}
