import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Screen showing sprint session history and upcoming scheduled sprints
class SprintHistoryScreen extends StatefulWidget {
  const SprintHistoryScreen({super.key});

  @override
  State<SprintHistoryScreen> createState() => _SprintHistoryScreenState();
}

class _SprintHistoryScreenState extends State<SprintHistoryScreen> {
  final StorageService _storageService = StorageService();
  List<SprintSession> _upcomingSprints = [];
  List<SprintSession> _pastSprints = [];
  SprintStatistics _stats = SprintStatistics.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    // Ensure sprints are scheduled
    await _storageService.ensureSprintsScheduled();

    final upcoming = await _storageService.getUpcomingSprints();
    final past = await _storageService.getPastSprints();
    final stats = await _storageService.getSprintStatistics();

    if (mounted) {
      setState(() {
        _upcomingSprints = upcoming;
        _pastSprints = past;
        _stats = stats;
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (dateOnly.isAtSameMomentAs(tomorrow)) {
      return 'Tomorrow';
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    }

    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  String _formatShortDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sprint Sessions'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsCard(),
                  const SizedBox(height: 24),
                  _buildUpcomingSection(),
                  const SizedBox(height: 24),
                  _buildHistorySection(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  value: '${_stats.currentStreak}',
                  label: 'Current\nStreak',
                ),
                _buildStatItem(
                  icon: Icons.emoji_events,
                  iconColor: Colors.amber,
                  value: '${_stats.longestStreak}',
                  label: 'Longest\nStreak',
                ),
                _buildStatItem(
                  icon: Icons.check_circle,
                  iconColor: Colors.green,
                  value: '${_stats.totalCompleted}',
                  label: 'Completed',
                ),
              ],
            ),
            if (_stats.totalScheduled > 0) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _stats.completionRate / 100,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  _stats.completionRate >= 80
                      ? Colors.green
                      : _stats.completionRate >= 50
                          ? Colors.orange
                          : Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_stats.completionRate.toStringAsFixed(0)}% completion rate',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildUpcomingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text(
                'Upcoming Sprints',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_upcomingSprints.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Text(
                  'No upcoming sprints scheduled',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < _upcomingSprints.length; i++) ...[
                  _buildUpcomingItem(_upcomingSprints[i]),
                  if (i < _upcomingSprints.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildUpcomingItem(SprintSession sprint) {
    final isToday = sprint.isToday;
    final isCompleted = sprint.completed;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isToday
              ? (isCompleted
                  ? Colors.green.withOpacity(0.15)
                  : Colors.orange.withOpacity(0.15))
              : Colors.purple.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isCompleted ? Icons.check : Icons.directions_run,
          color: isToday
              ? (isCompleted ? Colors.green : Colors.orange)
              : Colors.purple,
          size: 20,
        ),
      ),
      title: Text(
        _formatDate(sprint.date),
        style: TextStyle(
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text(
        isToday
            ? (isCompleted ? 'Completed' : 'Sprint day!')
            : _formatShortDate(sprint.date),
        style: TextStyle(
          color: isToday && !isCompleted ? Colors.orange : null,
        ),
      ),
      trailing: isCompleted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : isToday
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'TODAY',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                )
              : null,
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.history, size: 20),
              const SizedBox(width: 8),
              Text(
                'Past Sprints',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_pastSprints.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_run,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No sprint history yet',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your first sprint session!',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (int i = 0; i < _pastSprints.length; i++) ...[
                  _buildHistoryItem(_pastSprints[i]),
                  if (i < _pastSprints.length - 1)
                    const Divider(height: 1, indent: 56),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryItem(SprintSession sprint) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: sprint.completed
              ? Colors.green.withOpacity(0.15)
              : Colors.red.withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(
          sprint.completed ? Icons.check : Icons.close,
          color: sprint.completed ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(_formatDate(sprint.date)),
      subtitle: Text(
        sprint.completed ? 'Completed' : 'Missed',
        style: TextStyle(
          color: sprint.completed ? Colors.green : Colors.red,
        ),
      ),
      trailing: sprint.completed
          ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
          : const Icon(Icons.cancel, color: Colors.red, size: 20),
    );
  }
}
