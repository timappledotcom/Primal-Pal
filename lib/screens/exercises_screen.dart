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

  @override
  void initState() {
    super.initState();
    _loadScheduledExercises();
  }

  Future<void> _loadScheduledExercises() async {
    setState(() => _isLoading = true);
    var scheduled = await _storageService.loadScheduledExercises();

    // Reconciliation: Check history for completions that missed the schedule update
    if (scheduled != null && scheduled.isNotEmpty) {
      final history = await _storageService.loadExerciseHistory();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final todaysHistory = history.where((h) {
        final hDate = DateTime(
            h.completedAt.year, h.completedAt.month, h.completedAt.day);
        return hDate.isAtSameMomentAs(today);
      }).toList();

      bool changed = false;
      for (int i = 0; i < scheduled.length; i++) {
        if (!scheduled[i].isCompleted) {
          // Check if we have a history entry for this exercise ID
          final hasCompletion =
              todaysHistory.any((h) => h.exerciseId == scheduled[i].exerciseId);
          if (hasCompletion) {
            scheduled[i] = scheduled[i].markCompleted();
            changed = true;
          }
        }
      }

      if (changed) {
        await _storageService.saveScheduledExercises(scheduled);
      }
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

  Widget _buildGroupedList(BuildContext context) {
    final settings = context.watch<SettingsProvider>().settings;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final windowStart = DateTime(today.year, today.month, today.day,
        settings.activeWindowStart.hour, settings.activeWindowStart.minute);

    final windowEnd = DateTime(today.year, today.month, today.day,
        settings.activeWindowEnd.hour, settings.activeWindowEnd.minute);

    final duration = windowEnd.difference(windowStart);
    // Determine midpoint for split
    final midpoint = duration.isNegative
        ? DateTime(today.year, today.month, today.day, 12, 0)
        : windowStart.add(Duration(minutes: duration.inMinutes ~/ 2));

    final morningExercises = _scheduledExercises
        .where((e) => e.scheduledTime.isBefore(midpoint))
        .toList();

    final afternoonExercises = _scheduledExercises
        .where((e) => !e.scheduledTime.isBefore(midpoint))
        .toList();

    morningExercises.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
    afternoonExercises
        .sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (morningExercises.isNotEmpty) ...[
          _buildSectionHeader(context, 'Morning Session'),
          ...morningExercises.map((e) => _buildExerciseCard(context, e)),
          const SizedBox(height: 24),
        ],
        if (afternoonExercises.isNotEmpty) ...[
          _buildSectionHeader(context, 'Afternoon Session'),
          ...afternoonExercises.map((e) => _buildExerciseCard(context, e)),
          const SizedBox(height: 24), // Bottom padding
        ],
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 4.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
      ),
    );
  }

  Widget _buildExerciseCard(BuildContext context, ScheduledExercise scheduled) {
    final isCompleted = scheduled.isCompleted;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
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
        subtitle: Text(
          'Scheduled for ${TimeOfDay.fromDateTime(scheduled.scheduledTime).format(context)}',
        ),
        trailing: isCompleted
            ? null
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
