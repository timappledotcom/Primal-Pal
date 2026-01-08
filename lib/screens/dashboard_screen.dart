import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';

import 'active_session_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToWalk;
  final VoidCallback onNavigateToSprint;
  final VoidCallback onNavigateToExercises;
  final VoidCallback onNavigateToStatistics;

  const DashboardScreen({
    super.key,
    required this.onNavigateToWalk,
    required this.onNavigateToSprint,
    required this.onNavigateToExercises,
    required this.onNavigateToStatistics,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Primal Pal'),
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
          return ListView(

          padding: const EdgeInsets.all(16),
          children: [
            _buildTodayCard(context, settingsProvider),
            const SizedBox(height: 16),
            _buildFeatureSummaryCard(
              context,
              title: 'Daily Walk',
              icon: Icons.directions_walk,
              color: Colors.blue,
              onTap: onNavigateToWalk,
              description: 'Track your daily walk for consistency.',
            ),
            const SizedBox(height: 16),
            _buildFeatureSummaryCard(
              context,
              title: 'Sprint Session',
              icon: Icons.directions_run,
              color: Colors.orange,
              onTap: onNavigateToSprint,
              description: 'High intensity sprints 2x per month.',
            ),
            const SizedBox(height: 16),
            _buildActiveWindowCard(context, settingsProvider),
            const SizedBox(height: 16),
            _buildQuickStartButton(context, exerciseProvider, settingsProvider),
            const SizedBox(height: 16),
             _buildFeatureSummaryCard(
              context,
              title: 'Today\'s Exercises',
              icon: Icons.fitness_center,
              color: Colors.green,
              onTap: onNavigateToExercises,
              description: 'View your scheduled exercises for today.',
            ),             const SizedBox(height: 16),
             _buildFeatureSummaryCard(
              context,
              title: 'Statistics',
              icon: Icons.bar_chart,
              color: Colors.purple,
              onTap: onNavigateToStatistics,
              description: 'View detailed stats and trends.',
            ),          ],
        );
      },
    ));
  }

  Widget _buildTodayCard(BuildContext context, SettingsProvider settingsProvider) {
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

  Widget _buildFeatureSummaryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required String description,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveWindowCard(BuildContext context, SettingsProvider settingsProvider) {
    final now = TimeOfDay.now();
    final isInWindow = settingsProvider.settings.isInActiveWindow(now);
    final startTime = settingsProvider.settings.activeWindowStart;
    final endTime = settingsProvider.settings.activeWindowEnd;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isInWindow ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.access_time,
                color: isInWindow ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isInWindow ? 'Active Window Open' : 'Active Window Closed',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isInWindow ? Colors.green : Colors.grey[700],
                    ),
                  ),
                  Text(
                    '${startTime.format(context)} - ${endTime.format(context)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (isInWindow)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStartButton(BuildContext context, ExerciseProvider exerciseProvider, SettingsProvider settingsProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          final exercise = exerciseProvider.getRandomExercise(settingsProvider.settings);
          if (exercise != null) {
             exerciseProvider.setCurrentExerciseObject(exercise);
             Navigator.push(
               context,
               MaterialPageRoute(builder: (_) => const ActiveSessionScreen()),
             );
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('No exercises available for right now!')),
             );
          }
        },
        icon: const Icon(Icons.play_circle_filled),
        label: const Text('Quick Exercise Snack'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Theme.of(context).primaryColor,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
