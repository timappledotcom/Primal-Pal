import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import '../models/models.dart';
import '../services/services.dart';

class SprintScreen extends StatefulWidget {
  const SprintScreen({super.key});

  @override
  State<SprintScreen> createState() => _SprintScreenState();
}

class _SprintScreenState extends State<SprintScreen> {
  final StorageService _storageService = StorageService();
  
  // Sprint Data
  SprintSession? _todaysSprint;
  SprintSession? _nextSprint;
  List<SprintSession> _pastSprints = [];
  bool _isLoading = true;

  // Timer State
  int _remainingSeconds = 0;
  Timer? _sprintTimer;
  bool _isTimerRunning = false;


  @override
  void initState() {
    super.initState();
    _loadSprintData();
  }

  @override
  void dispose() {
    _sprintTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSprintData() async {
    setState(() => _isLoading = true);
    await _storageService.ensureSprintsScheduled();
    
    final todaysSprint = await _storageService.getTodaysSprint();
    final upcomingSprints = await _storageService.getUpcomingSprints();
    final pastSprints = await _storageService.getPastSprints();

    SprintSession? nextSprint;
    if (upcomingSprints.isNotEmpty) {
      nextSprint = upcomingSprints.firstWhere(
        (s) => !s.completed,
        orElse: () => upcomingSprints.first,
      );
    }

    if (mounted) {
      setState(() {
        _todaysSprint = todaysSprint;
        _nextSprint = nextSprint;
        _pastSprints = pastSprints;
        _isLoading = false;
      });
    }
  }

  Future<void> _completeSprint() async {
    final completed = await _storageService.completeTodaysSprint();
    if (completed != null) {
      await NotificationService().cancelSprintNotification();
      await _loadSprintData(); // Reload to update UI
    }
  }

  void _startTimer(int duration) {
    if (_todaysSprint == null || (_todaysSprint!.completed)) return;
    
    // Check if we already did enough reps? 
    // Actually, maybe user wants to do more? But "Mark Complete" usually appears.
    // Let's allow them to start unless strictly completed.
    
    _sprintTimer?.cancel();
    setState(() {
      _remainingSeconds = duration;
      _isTimerRunning = true;
    });

    _sprintTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timerFinished();
      }
    });
  }

  void _cancelTimer() {
    _sprintTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
      _remainingSeconds = 0;
    });
  }

  Future<void> _timerFinished() async {
    _sprintTimer?.cancel();
    setState(() {
      _isTimerRunning = false;
    });
    
    // Pulse vibrate (Annoying sequence)
    for (int i = 0; i < 15; i++) {
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 200));
        await HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 600));
    }
    
    // Increment rep
    final updatedSprint = await _storageService.incrementSprintRep();
    
    if (updatedSprint != null && mounted) {
       await _loadSprintData();
       
       final target = updatedSprint.targetSets ?? 0;
       final completed = updatedSprint.completedSets;
       
       if (completed >= target) {
         // Session Complete
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Sprint Session Complete!'),
              content: Text('You finished all $target reps! Great work!'),
              actions: [
                TextButton(
                  onPressed: () {
                     Navigator.pop(context);
                     _completeSprint();
                  },
                  child: const Text('FINISH'),
                ),
              ],
            ),
          );
       } else {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Rep Completed!'),
              content: Text('Rep $completed of $target done.\nRest, then start the next one.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
       }
    }
  }

  String _formatDate(DateTime date) {
    // Simplified date formatter
    return '${date.day}/${date.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isSprintDay = _todaysSprint != null;
    final isCompleted = _todaysSprint?.completed ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Sprint Session')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Status Card
              _buildStatusCard(isSprintDay, isCompleted),
              const SizedBox(height: 16),
              
              // Timer Section
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text('Sprint Timer', style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      if (_isTimerRunning)
                        Column(
                          children: [
                             Text(
                              '$_remainingSeconds',
                              style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                             ElevatedButton(
                              onPressed: _cancelTimer,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              child: const Text('CANCEL'),
                            ),
                          ],
                        )
                      else
                        Wrap(
                          spacing: 16,
                          children: [
                            _buildTimerButton(10),
                            _buildTimerButton(15),
                            _buildTimerButton(20),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // History Section
              if (_pastSprints.isNotEmpty) ...[
                Text('History', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Card(
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pastSprints.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final sprint = _pastSprints[index];
                      return ListTile(
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(_formatDate(sprint.date)),
                        subtitle: Text(sprint.completed ? 'Completed' : 'Skipped'),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildStatusCard(bool isSprintDay, bool isCompleted) {
    if (isSprintDay && !isCompleted && _todaysSprint?.targetSets != null) {
      final target = _todaysSprint!.targetSets!;
      final current = _todaysSprint!.completedSets;
      // If user hasn't started, maybe "Surprise Reps" or show it?
      // Requirement: "never know how many you are doing until the time comes"
      // This could mean: 
      // 1. Hidden until first start? 
      // 2. Or "until the day arrives".
      // Given "on sprint day you never know... until the time comes", it probably means revealed on the day.
      // So showing it now (on the day) is correct.
      
      return Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
               Text(
                 'Today\'s Mission',
                 style: Theme.of(context).textTheme.titleLarge,
               ),
               const SizedBox(height: 8),
               Text(
                 'Complete $target Sprints',
                 style: Theme.of(context).textTheme.headlineSmall,
               ),
               const SizedBox(height: 16),
               LinearProgressIndicator(
                  value: target > 0 ? current / target : 0,
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
               ),
               const SizedBox(height: 8),
               Text('$current of $target Completed'),
            ],
          ),
        ),
      );
    }

    return Card(
      color: isSprintDay ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.directions_run,
                  size: 48,
                  color: isSprintDay ? Colors.orange : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       Text(
                         isSprintDay ? 'Today is Sprint Day!' : 'Rest Day',
                         style: Theme.of(context).textTheme.titleLarge,
                       ),
                       if (_nextSprint != null && !isSprintDay)
                         Text('Next sprint: ${_formatDate(_nextSprint!.date)}'),
                    ],
                  ),
                ),
              ],
            ),
            if (isSprintDay && !isCompleted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _completeSprint,
                  icon: const Icon(Icons.check),
                  label: const Text('MARK COMPLETE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ] else if (isSprintDay && isCompleted) ...[
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.check, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Completed!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimerButton(int seconds) {
    return ElevatedButton(
      onPressed: () => _startTimer(seconds),
      child: Text('${seconds}s'),
    );
  }
}
