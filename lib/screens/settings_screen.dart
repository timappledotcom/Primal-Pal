import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';
import 'onboarding_screen.dart';

/// Settings screen for configuring sport days and active window
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final settings = provider.settings;

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: [
              // Sport Days Section
              _buildSectionTitle(context, 'SPORT MODE DAYS'),
              const SizedBox(height: 12),
              _buildDaySelector(context, provider, settings),

              const SizedBox(height: 32),

              // Active Window Section
              _buildSectionTitle(context, 'ACTIVE WINDOW'),
              const SizedBox(height: 12),
              _buildTimeSelector(context, provider, settings),

              const SizedBox(height: 32),

              // Snacks per day
              _buildSectionTitle(context, 'DAILY SNACKS'),
              const SizedBox(height: 12),
              _buildSnacksSelector(context, provider, settings),

              const SizedBox(height: 32),

              // Measurement Units
              _buildSectionTitle(context, 'UNITS'),
              const SizedBox(height: 12),
              _buildUnitSelector(context, provider, settings),

              const SizedBox(height: 32),

              // Exercise Management
              _buildSectionTitle(context, 'MANAGE EXERCISES'),
              const SizedBox(height: 12),
              _buildExerciseManagementButton(context),

              const SizedBox(height: 32),

              // Actions
              _buildShuffleExercisesButton(context),

              const SizedBox(height: 12),

              _buildRescheduleButton(context),

              const SizedBox(height: 16),

              // How It Works link
              _buildHowItWorksButton(context),

              const SizedBox(height: 16),

              // Reset exercises data
              _buildResetExercisesButton(context),

              const SizedBox(height: 48),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }

  Widget _buildDaySelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendChip(context, '🧘 Sport (Mobility)', Colors.orange),
              const SizedBox(width: 16),
              _buildLegendChip(context, '💪 Rest (Strength)', Colors.blue),
            ],
          ),
          const SizedBox(height: 20),
          // Day buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final isSportDay = settings.isSportDay(weekday);
              final dayLetter = _getDayLetter(weekday);

              return GestureDetector(
                onTap: () => provider.toggleSportDay(weekday),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: isSportDay
                        ? Colors.orange.withOpacity(0.9)
                        : Colors.blue.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: (isSportDay ? Colors.orange : Colors.blue)
                            .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      dayLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          // Day labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              final weekday = index + 1;
              return SizedBox(
                width: 42,
                child: Text(
                  AppSettings.getWeekdayShortName(weekday),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitSelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: const Text('Use Imperial Units (Miles)'),
        subtitle: const Text('Switch between Kilometers and Miles'),
        value: settings.useImperialUnits,
        activeThumbColor: Theme.of(context).colorScheme.primary,
        onChanged: (value) => provider.setUseImperialUnits(value),
      ),
    );
  }

  Widget _buildLegendChip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }

  String _getDayLetter(int weekday) {
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return letters[weekday - 1];
  }

  Widget _buildTimeSelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTimeButton(
              context,
              'Start',
              settings.activeWindowStart,
              () => _selectTime(
                context,
                settings.activeWindowStart,
                (time) => provider.setActiveWindowStart(time),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Icon(
              Icons.arrow_forward,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Expanded(
            child: _buildTimeButton(
              context,
              'End',
              settings.activeWindowEnd,
              () => _selectTime(
                context,
                settings.activeWindowEnd,
                (time) => provider.setActiveWindowEnd(time),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeButton(
    BuildContext context,
    String label,
    TimeOfDay time,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppSettings.formatTimeOfDay(time),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(
    BuildContext context,
    TimeOfDay initialTime,
    Function(TimeOfDay) onSelected,
  ) async {
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (time != null) {
      onSelected(time);
    }
  }

  Widget _buildSnacksSelector(
    BuildContext context,
    SettingsProvider provider,
    AppSettings settings,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton.filled(
            onPressed: settings.snacksPerDay > 1
                ? () => provider.setSnacksPerDay(settings.snacksPerDay - 1)
                : null,
            icon: const Icon(Icons.remove),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                Text(
                  '${settings.snacksPerDay}',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'per day',
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filled(
            onPressed: settings.snacksPerDay < 12
                ? () => provider.setSnacksPerDay(settings.snacksPerDay + 1)
                : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildShuffleExercisesButton(BuildContext context) {
    return FilledButton(
      onPressed: () => _shuffleExercises(context),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shuffle),
          SizedBox(width: 8),
          Text('Shuffle Today\'s Exercises'),
        ],
      ),
    );
  }

  Widget _buildRescheduleButton(BuildContext context) {
    return FilledButton.tonal(
      onPressed: () => _rescheduleNotifications(context),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.refresh),
          SizedBox(width: 8),
          Text('Reschedule Today\'s Notifications'),
        ],
      ),
    );
  }

  Widget _buildHowItWorksButton(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OnboardingScreen(
              isRevisit: true,
              onComplete: () => Navigator.pop(context),
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.help_outline),
          SizedBox(width: 8),
          Text('How It Works'),
        ],
      ),
    );
  }

  Future<void> _shuffleExercises(BuildContext context) async {
    final exerciseProvider = context.read<ExerciseProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    // Reset today's exercises to make all of them available again
    await exerciseProvider.resetTodaysExercises(settingsProvider.settings);

    // Get the newly available exercises
    final availableExercises = exerciseProvider
        .getAvailableExercisesForToday(settingsProvider.settings);

    // Reschedule notifications with the fresh pool
    await NotificationService().scheduleDailyNotifications(
      availableExercises: availableExercises,
      settings: settingsProvider.settings,
    );

    await StorageService().saveLastScheduledDate(DateTime.now());

    if (context.mounted) {
      final isSportDay = settingsProvider.settings.isTodaySportDay();
      final exerciseType = isSportDay ? 'mobility' : 'strength';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Shuffled! ${availableExercises.length} $exerciseType exercises ready 🎲'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _rescheduleNotifications(BuildContext context) async {
    final exerciseProvider = context.read<ExerciseProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    final availableExercises = exerciseProvider
        .getAvailableExercisesForToday(settingsProvider.settings);

    await NotificationService().scheduleDailyNotifications(
      availableExercises: availableExercises,
      settings: settingsProvider.settings,
    );

    await StorageService().saveLastScheduledDate(DateTime.now());

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Notifications rescheduled! 🎯'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildResetExercisesButton(BuildContext context) {
    return TextButton(
      onPressed: () => _resetExercises(context),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.all(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.restart_alt,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          Text(
            'Reset Exercise Data',
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _resetExercises(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Exercise Data?'),
        content: const Text(
          'This will reload all 32 exercises with fresh data. '
          'Your rep progression will be reset to defaults.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final exerciseProvider = context.read<ExerciseProvider>();
    await exerciseProvider.resetToDefaults();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Exercise data reset! 32 exercises loaded 💪'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Widget _buildExerciseManagementButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ExerciseManagementScreen()),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.fitness_center,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: const Text('Select Exercises'),
        subtitle: const Text('Enable or disable exercises in rotation'),
        trailing: const Icon(Icons.chevron_right),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

/// Screen for managing which exercises are enabled/disabled
class ExerciseManagementScreen extends StatelessWidget {
  const ExerciseManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Exercises'),
        centerTitle: true,
      ),
      body: Consumer<ExerciseProvider>(
        builder: (context, provider, _) {
          final strengthExercises = provider.strengthExercises;
          final mobilityExercises = provider.mobilityExercises;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Strength exercises section
              _buildExerciseSection(
                context,
                provider,
                'STRENGTH EXERCISES (Rest Days)',
                strengthExercises,
                Colors.blue,
              ),

              const SizedBox(height: 24),

              // Mobility exercises section
              _buildExerciseSection(
                context,
                provider,
                'MOBILITY EXERCISES (Sport Days)',
                mobilityExercises,
                Colors.orange,
              ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExerciseSection(
    BuildContext context,
    ExerciseProvider provider,
    String title,
    List<Exercise> exercises,
    Color color,
  ) {
    final enabledCount = exercises.where((e) => e.isEnabled).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const Spacer(),
            Text(
              '$enabledCount/${exercises.length} enabled',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final exercise = entry.value;
              final isLast = index == exercises.length - 1;

              return Column(
                children: [
                  _buildExerciseTile(context, provider, exercise, color),
                  if (!isLast)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context)
                          .colorScheme
                          .outline
                          .withOpacity(0.1),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseTile(
    BuildContext context,
    ExerciseProvider provider,
    Exercise exercise,
    Color color,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: exercise.isEnabled
              ? color.withOpacity(0.15)
              : Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          exercise.type == ExerciseType.strength
              ? Icons.fitness_center
              : Icons.self_improvement,
          color: exercise.isEnabled ? color : Colors.grey,
          size: 20,
        ),
      ),
      title: Text(
        exercise.name,
        style: TextStyle(
          color: exercise.isEnabled ? null : Colors.grey,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Row(
        children: [
          Text(
            exercise.isTimed
                ? '${exercise.currentReps}s'
                : '${exercise.currentReps} reps',
            style: TextStyle(
              fontSize: 12,
              color: exercise.isEnabled
                  ? Theme.of(context).colorScheme.outline
                  : Colors.grey,
            ),
          ),
          if (exercise.isBilateral) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Both sides',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.teal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
      trailing: Switch.adaptive(
        value: exercise.isEnabled,
        onChanged: (value) => provider.setExerciseEnabled(exercise.id, value),
        activeColor: color,
      ),
    );
  }
}
