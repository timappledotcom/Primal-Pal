import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/providers.dart';
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
  List<DailyWalk> _allWalks = [];
  WalkStatistics _walkStats = WalkStatistics.empty();
  SprintStatistics _sprintStats = SprintStatistics.empty();
  List<ExerciseHistoryEntry> _exerciseHistory = [];
  bool _isLoading = true;

  // Walk period filter
  String _walkPeriod = 'week'; // 'week', 'month', 'year', 'all'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    // Listen for changes in exercises/sprints to update stats
    final provider = context.read<ExerciseProvider>();
    provider.addListener(_loadData);
  }

  @override
  void dispose() {
    final provider = context.read<ExerciseProvider>();
    provider.removeListener(_loadData);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Avoid setting state if not mounted
    if (!mounted) return;
    
    // Load Walks
    final walks = await _storageService.loadDailyWalks();
    
    // Load Sprints
    final sprintStats = await _storageService.getSprintStatistics();

    // Load Exercise History
    final history = await _storageService.loadExerciseHistory();

    if (mounted) {
      setState(() {
        _allWalks = walks;
        _walkStats = _calculateWalkStats(walks, _walkPeriod);
        _sprintStats = sprintStats;
        _exerciseHistory = history;
        _isLoading = false;
      });
    }
  }

  WalkStatistics _calculateWalkStats(List<DailyWalk> walks, String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    DateTime? startDate;
    switch (period) {
      case 'week':
        startDate = today.subtract(const Duration(days: 7));
        break;
      case 'month':
        startDate = today.subtract(const Duration(days: 30));
        break;
      case 'year':
        startDate = today.subtract(const Duration(days: 365));
        break;
      case 'all':
      default:
        startDate = null;
    }

    final filteredWalks = startDate != null
        ? walks.where((w) => w.date.isAfter(startDate!)).toList()
        : walks;

    return WalkStatistics.fromWalks(filteredWalks, periodStart: startDate, periodEnd: today);
  }

  void _setWalkPeriod(String period) {
    setState(() {
      _walkPeriod = period;
      _walkStats = _calculateWalkStats(_allWalks, period);
    });
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
    final settings = context.watch<SettingsProvider>().settings;
    final useImperial = settings.useImperialUnits;

    // Format distance based on units preference
    final distanceValue = useImperial 
        ? (_walkStats.totalDistanceKm * 0.621371) // km to miles
        : _walkStats.totalDistanceKm;
    final distanceUnit = useImperial ? 'mi' : 'km';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period selector
        _buildPeriodSelector(),
        const SizedBox(height: 16),

        // Total Time and Distance
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Time',
                _walkStats.formattedTotalTime,
                Icons.timer,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Distance',
                '${distanceValue.toStringAsFixed(2)} $distanceUnit',
                Icons.straighten,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Walks completed
        _buildStatCard(
          'Walks Completed',
          '${_walkStats.completedDays}',
          Icons.directions_walk,
          Colors.green,
        ),
        const SizedBox(height: 16),

        // Streaks
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

        // Average duration
        _buildStatCard(
          'Average Duration',
          _walkStats.formattedAverageTime,
          Icons.speed,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildPeriodButton('Week', 'week'),
          _buildPeriodButton('Month', 'month'),
          _buildPeriodButton('Year', 'year'),
          _buildPeriodButton('All', 'all'),
        ],
      ),
    );
  }

  Widget _buildPeriodButton(String label, String value) {
    final isSelected = _walkPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setWalkPeriod(value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
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
