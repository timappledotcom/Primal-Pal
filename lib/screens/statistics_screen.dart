import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StorageService _storageService = StorageService();

  // Data
  WalkStatistics _walkStats = WalkStatistics.empty();
  SprintStatistics _sprintStats = SprintStatistics.empty();
  List<ExerciseHistoryEntry> _exerciseHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load Walks
    final walks = await _storageService.loadDailyWalks();
    final walkStats = WalkStatistics.fromWalks(walks);

    // Load Sprints
    final sprintStats = await _storageService.getSprintStatistics();

    // Load Exercise History
    final history = await _storageService.loadExerciseHistory();

    if (mounted) {
      setState(() {
        _walkStats = walkStats;
        _sprintStats = sprintStats;
        _exerciseHistory = history;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Walks'),
            Tab(text: 'Sprints'),
            Tab(text: 'Exercises'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWalkStats(),
                _buildSprintStats(),
                _buildExerciseStats(),
              ],
            ),
    );
  }

  Widget _buildWalkStats() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Total Distance',
          '${(_walkStats.totalSeconds / 3600).toStringAsFixed(1)} hours',
          Icons.directions_walk,
          Colors.blue,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Current Streak',
                '${_walkStats.currentStreak} days',
                Icons.local_fire_department,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Longest Streak',
                '${_walkStats.longestStreak} days',
                Icons.emoji_events,
                Colors.amber,
              ),
            ),
          ],
        ),
         const SizedBox(height: 16),
        _buildStatCard(
           'Completion Rate',
           '${_walkStats.completionRate.toStringAsFixed(1)}%',
           Icons.pie_chart,
           Colors.purple,
        ),
         const SizedBox(height: 16),
         _buildStatCard(
           'Average Duration',
           _walkStats.formattedAverageTime,
           Icons.timer,
           Colors.green,
         ),
      ],
    );
  }

  Widget _buildSprintStats() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatCard(
          'Completion Rate',
          '${_sprintStats.completionRate.toStringAsFixed(1)}%',
          Icons.speed,
          Colors.red,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
             Expanded(
              child: _buildStatCard(
                'Total Completed',
                '${_sprintStats.totalCompleted}',
                Icons.check_circle,
                Colors.green,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Skipped',
                '${_sprintStats.totalScheduled - _sprintStats.totalCompleted}',
                Icons.cancel,
                Colors.grey,
              ),
            ),
          ],
        ),
         const SizedBox(height: 16),
         _buildStatCard(
           'Current Streak',
           '${_sprintStats.currentStreak}',
           Icons.local_fire_department,
           Colors.orange,
         ),
      ],
    );
  }

  Widget _buildExerciseStats() {
    // Process history data
    final totalCount = _exerciseHistory.length;
    
    // Group by exercise name
    final Map<String, int> countsByName = {};
    for (var entry in _exerciseHistory) {
      countsByName[entry.exerciseName] = (countsByName[entry.exerciseName] ?? 0) + 1;
    }
    
    // Sort by count
    final sortedExercises = countsByName.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Calculate this week / month
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneMonthAgo = now.subtract(const Duration(days: 30));
    
    final lastWeekCount = _exerciseHistory.where((e) => e.completedAt.isAfter(oneWeekAgo)).length;
    final lastMonthCount = _exerciseHistory.where((e) => e.completedAt.isAfter(oneMonthAgo)).length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
           children: [
             Expanded(
               child: _buildStatCard(
                 'Total Completed',
                 '$totalCount',
                 Icons.numbers,
                 Colors.blue,
               ),
             ),
             const SizedBox(width: 16),
             Expanded(
               child: _buildStatCard(
                 'Last 7 Days',
                 '$lastWeekCount',
                 Icons.calendar_view_week,
                 Colors.green,
               ),
             ),
           ],
        ),
        const SizedBox(height: 16),
         _buildStatCard(
           'Last 30 Days',
           '$lastMonthCount',
           Icons.calendar_month,
           Colors.purple,
         ),
        const SizedBox(height: 24),
        Text('Most Frequent Exercises', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (sortedExercises.isEmpty)
          const Text('No exercises completed yet.', style: TextStyle(color: Colors.grey))
        else
          ...sortedExercises.map((e) => ListTile(
            title: Text(e.key),
            trailing: Chip(label: Text('${e.value}')),
            contentPadding: EdgeInsets.zero,
            dense: true,
          )),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
