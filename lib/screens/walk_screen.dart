import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/services.dart';

// Top-level callback for foreground task
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(WalkTaskHandler());
}

class WalkTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Called when the foreground service starts
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // This is called every 5 seconds (as configured in ForegroundTaskOptions)
    // Update notification if needed
    FlutterForegroundTask.updateService(
      notificationTitle: 'Walk Tracking Active',
      notificationText: 'Tracking your walk...',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Called when the foreground service stops
  }

  @override
  void onNotificationButtonPressed(String id) {
    // Handle notification button press if you add buttons
  }

  @override
  void onNotificationPressed() {
    // Called when the notification is pressed
    FlutterForegroundTask.launchApp('/walk');
  }
}

class WalkScreen extends StatefulWidget {
  const WalkScreen({super.key});

  @override
  State<WalkScreen> createState() => _WalkScreenState();
}

class _WalkScreenState extends State<WalkScreen> {
  final StorageService _storageService = StorageService();

  // Timer State
  int _todayTotalSeconds = 0;
  double _todayDistanceMeters = 0;
  bool _isWalkTimerRunning = false;
  Timer? _walkTimer;
  DateTime? _walkStartTime;

  // Location State
  StreamSubscription<Position>? _positionStream;
  Position? _lastPosition;
  double _sessionDistanceMeters = 0; // Distance in current session

  // History State
  List<DailyWalk> _allWalks = [];
  WalkStatistics _weeklyStats = WalkStatistics.empty();
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _initForegroundTask();
    _loadTodaysWalk();
    _loadHistoryData();
  }

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'walk_tracking',
        channelName: 'Walk Tracking',
        channelDescription: 'Notification shown during walk tracking',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    _positionStream?.cancel();
    // Ensure wakelock is disabled when screen is disposed
    WakelockPlus.disable();
    // Stop foreground service if running
    FlutterForegroundTask.stopService();
    super.dispose();
  }

  Future<void> _loadTodaysWalk() async {
    final todaysWalk = await _storageService.getTodaysWalk();
    if (mounted) {
      setState(() {
        _todayTotalSeconds = todaysWalk?.totalSeconds ?? 0;
        _todayDistanceMeters = todaysWalk?.distanceMeters ?? 0;
      });
    }
  }

  Future<void> _loadHistoryData() async {
    setState(() => _isLoadingHistory = true);
    final allWalks = await _storageService.loadDailyWalks();
    final weekWalks = await _storageService.getThisWeeksWalks();

    // Sort by date descending
    allWalks.sort((a, b) => b.date.compareTo(a.date));

    if (mounted) {
      setState(() {
        _allWalks = allWalks;
        _weeklyStats = WalkStatistics.fromWalks(weekWalks);
        _isLoadingHistory = false;
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

  Future<void> _startWalkTimer() async {
    // Enable wakelock to keep screen and timer active
    try {
      await WakelockPlus.enable();
    } catch (e) {
      debugPrint('Failed to enable wakelock: $e');
    }

    // 1. Permission Check FIRST (required before starting foreground service with location type on SDK 36+)
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Location services disabled. Distance tracking unavailable.')),
        );
      }
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Location permissions denied. Tracking time only.')),
        );
      }
    }

    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Location permissions permanently denied. Tracking time only.')),
      );
    }

    // 2. Start foreground service AFTER permission is granted
    // Only start with location type if we have location permission
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.restartService();
      } else {
        await FlutterForegroundTask.startService(
          notificationTitle: 'Walk Tracking Active',
          notificationText: 'Tracking your walk...',
          callback: startCallback,
        );
      }
    }

    setState(() {
      _isWalkTimerRunning = true;
      _walkStartTime = DateTime.now();
      _sessionDistanceMeters = 0;
      _lastPosition = null;
    });

    _walkTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _todayTotalSeconds++;
      });
    });

    // 2. Start Location Stream if permitted
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      // High accuracy for walking
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy
            .bestForNavigation, // High power / GPS, good for walk tracking
        distanceFilter: 5, // Minimum change (meters)
      );

      _positionStream =
          Geolocator.getPositionStream(locationSettings: locationSettings)
              .listen(
        (Position position) {
          if (_isWalkTimerRunning) {
            if (_lastPosition != null) {
              final distance = Geolocator.distanceBetween(
                  _lastPosition!.latitude,
                  _lastPosition!.longitude,
                  position.latitude,
                  position.longitude);

              if (distance > 0) {
                setState(() {
                  _sessionDistanceMeters += distance;
                  _todayDistanceMeters += distance;
                });
              }
            }
            _lastPosition = position;
          }
        },
        onError: (e) {
          print('Location Stream Error: $e');
        },
      );
    }
  }

  Future<void> _stopWalkTimer() async {
    _walkTimer?.cancel();
    _walkTimer = null;

    _positionStream?.cancel();
    _positionStream = null;

    // Stop foreground service
    await FlutterForegroundTask.stopService();

    // Disable wakelock when timer stops
    try {
      await WakelockPlus.disable();
    } catch (e) {
      debugPrint('Failed to disable wakelock: $e');
    }

    // Save the walk
    if (_walkStartTime != null) {
      final seconds = DateTime.now().difference(_walkStartTime!).inSeconds;

      await _storageService.addSecondsToTodaysWalk(seconds,
          extraDistance: _sessionDistanceMeters);

      // Reload everything to ensure consistency
      await _loadTodaysWalk();
      await _loadHistoryData();
    }

    setState(() {
      _isWalkTimerRunning = false;
      _walkStartTime = null;
      _sessionDistanceMeters = 0;
      _lastPosition = null;
    });
  }

  String _formatWalkTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double meters, bool useImperial) {
    if (useImperial) {
      // Convert to miles (1 meter = 0.000621371 miles)
      final miles = meters * 0.000621371;
      return '${miles.toStringAsFixed(2)} mi';
    } else {
      if (meters >= 1000) {
        return '${(meters / 1000).toStringAsFixed(2)} km';
      } else {
        return '${meters.toStringAsFixed(0)} m';
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (DateTime(date.year, date.month, date.day).isAtSameMomentAs(today)) {
      return 'Today';
    }
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    // Watch settings for unit changes
    final settingsProvider = context.watch<SettingsProvider>();
    final useImperial = settingsProvider.settings.useImperialUnits;

    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(title: const Text('Daily Walk')),
        body: Column(
          children: [
            // Timer Section (Top)
            Container(
              padding: const EdgeInsets.all(24),
              color: Theme.of(context).cardColor,
              child: Column(
                children: [
                  Text(
                    'Today\'s Activity',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Time
                      Column(
                        children: [
                          Text(
                            _formatWalkTime(_todayTotalSeconds),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontSize: 32,
                                  color:
                                      _isWalkTimerRunning ? Colors.green : null,
                                ),
                          ),
                          const Text('Time',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                      const SizedBox(width: 32),
                      // Distance
                      Column(
                        children: [
                          Text(
                            _formatDistance(_todayDistanceMeters, useImperial),
                            style: Theme.of(context)
                                .textTheme
                                .displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  fontSize: 32,
                                  color:
                                      _isWalkTimerRunning ? Colors.blue : null,
                                ),
                          ),
                          const Text('Distance',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _toggleWalkTimer,
                      icon: Icon(
                          _isWalkTimerRunning ? Icons.stop : Icons.play_arrow),
                      label: Text(_isWalkTimerRunning
                          ? 'STOP WORKOUT'
                          : 'START WORKOUT'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _isWalkTimerRunning ? Colors.red : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // History Section
            Expanded(
              child: _isLoadingHistory
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: _allWalks.length + 1, // +1 for header
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildStatsHeader();
                        }
                        final walk = _allWalks[index - 1];
                        return ListTile(
                          title: Text(_formatDate(walk.date)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatWalkTime(walk.totalSeconds),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (walk.distanceMeters > 0)
                                Text(
                                  _formatDistance(
                                      walk.distanceMeters, useImperial),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Weekly Avg Time',
              _formatWalkTime(_weeklyStats.averageDurationSeconds.toInt())),
          // Add detailed stats later if needed
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
