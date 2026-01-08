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
    final scheduled = await _storageService.loadScheduledExercises();
    if (mounted) {
      setState(() {
        _scheduledExercises = scheduled ?? [];
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshExercises() async {
      final exerciseProvider = context.read<ExerciseProvider>();
      final settingsProvider = context.read<SettingsProvider>();
      
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
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _scheduledExercises.length,
                  itemBuilder: (context, index) {
                    final scheduled = _scheduledExercises[index];
                    final exerciseName = scheduled.exerciseName;
                    final isCompleted = scheduled.isCompleted;
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isCompleted ? Colors.green.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
                          child: Icon(
                            isCompleted ? Icons.check : Icons.fitness_center,
                            color: isCompleted ? Colors.green : Colors.blue,
                          ),
                        ),
                        title: Text(
                          exerciseName,
                          style: TextStyle(
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? Colors.grey : null,
                          ),
                        ),
                        subtitle: Text(
                          'Scheduled for ${TimeOfDay.fromDateTime(scheduled.scheduledTime).format(context)}', // Simplified
                        ),
                        trailing: isCompleted
                             ? null
                             : IconButton(
                                 icon: const Icon(Icons.check_circle_outline),
                                 onPressed: () {
                                    // Navigate to start
                                    final provider = context.read<ExerciseProvider>();
                                    provider.setCurrentExercise(scheduled.exerciseId);
                                    Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
                                    ).then((_) => _refreshExercises()); // Refresh on return
                                 },
                               ),
                        onTap: () {
                           // Navigate to exercise details or start?
                            final provider = context.read<ExerciseProvider>();
                            provider.setCurrentExercise(scheduled.exerciseId);
                            Navigator.push(
                              context, 
                              MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
                            ).then((_) => _refreshExercises());
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
