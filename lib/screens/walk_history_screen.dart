import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/services.dart';

/// Screen showing walk history with daily times, weekly and monthly averages
class WalkHistoryScreen extends StatefulWidget {
  const WalkHistoryScreen({super.key});

  @override
  State<WalkHistoryScreen> createState() => _WalkHistoryScreenState();
}

class _WalkHistoryScreenState extends State<WalkHistoryScreen> {
  final StorageService _storageService = StorageService();
  List<DailyWalk> _allWalks = [];
  WalkStatistics _weeklyStats = WalkStatistics.empty();
  WalkStatistics _monthlyStats = WalkStatistics.empty();
  WalkStatistics _allTimeStats = WalkStatistics.empty();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final allWalks = await _storageService.loadDailyWalks();
    final weekWalks = await _storageService.getThisWeeksWalks();
    final monthWalks = await _storageService.getThisMonthsWalks();

    // Sort by date descending (most recent first)
    allWalks.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _allWalks = allWalks;
        _weeklyStats = WalkStatistics.fromWalks(weekWalks);
        _monthlyStats = WalkStatistics.fromWalks(monthWalks);
        _allTimeStats = WalkStatistics.fromWalks(allWalks);
        _isLoading = false;
      });
    }
  }

  String _formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly.isAtSameMomentAs(today)) {
      return 'Today';
    } else if (dateOnly.isAtSameMomentAs(yesterday)) {
      return 'Yesterday';
    }

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Walk History'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatsOverview(),
                  const SizedBox(height: 24),
                  _buildAveragesCard(),
                  const SizedBox(height: 24),
                  _buildHistoryHeader(),
                  const SizedBox(height: 8),
                  _buildHistoryList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsOverview() {
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
                  value: '${_allTimeStats.currentStreak}',
                  label: 'Current\nStreak',
                ),
                _buildStatItem(
                  icon: Icons.emoji_events,
                  iconColor: Colors.amber,
                  value: '${_allTimeStats.longestStreak}',
                  label: 'Longest\nStreak',
                ),
                _buildStatItem(
                  icon: Icons.calendar_today,
                  iconColor: Colors.blue,
                  value: '${_allTimeStats.completedDays}',
                  label: 'Days\nWalked',
                ),
              ],
            ),
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

  Widget _buildAveragesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Averages',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _buildAverageRow(
              label: 'This Week',
              average: _weeklyStats.formattedAverageTime,
              total: _formatDuration(_weeklyStats.totalSeconds),
              days: _weeklyStats.completedDays,
            ),
            const Divider(height: 24),
            _buildAverageRow(
              label: 'This Month',
              average: _monthlyStats.formattedAverageTime,
              total: _formatDuration(_monthlyStats.totalSeconds),
              days: _monthlyStats.completedDays,
            ),
            const Divider(height: 24),
            _buildAverageRow(
              label: 'All Time',
              average: _allTimeStats.formattedAverageTime,
              total: _formatDuration(_allTimeStats.totalSeconds),
              days: _allTimeStats.completedDays,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAverageRow({
    required String label,
    required String average,
    required String total,
    required int days,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Avg: $average',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Total: $total ($days days)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          const Icon(Icons.history, size: 20),
          const SizedBox(width: 8),
          Text(
            'Recent Activity',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_allWalks.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No walks recorded yet',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start your first walk from the home screen!',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Only show walks with time recorded, limit to last 30 days
    final walksWithTime = _allWalks
        .where((w) => w.totalSeconds > 0)
        .take(30)
        .toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < walksWithTime.length; i++) ...[
            _buildHistoryItem(walksWithTime[i]),
            if (i < walksWithTime.length - 1)
              const Divider(height: 1, indent: 56),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryItem(DailyWalk walk) {
    final isToday = walk.isToday;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isToday
              ? Colors.green.withOpacity(0.15)
              : Colors.blue.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.directions_walk,
          color: isToday ? Colors.green : Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        _formatDate(walk.date),
        style: TextStyle(
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: Text(
        walk.formattedTime,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green[700],
            ),
      ),
    );
  }
}
