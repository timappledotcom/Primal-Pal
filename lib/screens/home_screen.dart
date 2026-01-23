import 'package:flutter/material.dart';
import 'screens.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      DashboardScreen(
        onNavigateToWalk: () => _onItemTapped(1),
        onNavigateToSprint: () => _onItemTapped(2),
        onNavigateToExercises: () => _onItemTapped(3),
        onNavigateToStatistics: () => _onItemTapped(4),
      ),
      const WalkScreen(),
      const SprintScreen(),
      const ExercisesScreen(),
      const StatisticsScreen(),
    ];

    return Scaffold(
      body: IndexedStack( // Use IndexedStack to preserve state of pages
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_walk),
            label: 'Walk',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run),
            label: 'Sprint',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fitness_center),
            label: 'Exercises',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Stats',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed, // Needed for 4+ items
      ),
    );
  }
}
