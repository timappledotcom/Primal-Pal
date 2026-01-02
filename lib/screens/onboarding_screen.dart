import 'package:flutter/material.dart';

/// Onboarding screen explaining the Greasing the Groove system
class OnboardingScreen extends StatefulWidget {
  final bool isRevisit;
  final VoidCallback onComplete;

  const OnboardingScreen({
    super.key,
    this.isRevisit = false,
    required this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = [
    _OnboardingPage(
      icon: Icons.auto_awesome,
      title: 'The Primal Blueprint',
      subtitle: 'Live Like Your Ancestors',
      body:
          '''Welcome to Primal Pal—an app built around Mark Sisson's 10 Primal Laws.

These laws are based on how our ancestors lived for millions of years. Our genes expect certain inputs to thrive: movement, sunlight, real food, and rest.

Let's explore how this app helps you live primally in the modern world.''',
    ),
    _OnboardingPage(
      icon: Icons.restaurant,
      title: '1. Eat Animals & Plants',
      subtitle: 'Fuel Your Body Right',
      body:
          '''Our ancestors ate what they could hunt and gather—meat, fish, vegetables, fruits, nuts, and seeds.

While this app doesn't track your food, remember: no amount of exercise can outrun a bad diet.

Eat real, whole foods. Avoid processed junk. Your workouts will thank you.''',
    ),
    _OnboardingPage(
      icon: Icons.directions_walk,
      title: '2. Move Around a Lot',
      subtitle: 'At a Slow Pace',
      body:
          '''Our ancestors walked 5-10 miles daily—foraging, hunting, and exploring.

That's why we track your Daily Walk. Hit that start button and accumulate walking time throughout the day. Aim for at least 30 minutes.

Low-level aerobic activity burns fat, improves mood, and builds the foundation for all other fitness.''',
    ),
    _OnboardingPage(
      icon: Icons.fitness_center,
      title: '3. Lift Heavy Things',
      subtitle: 'Build Functional Strength',
      body:
          '''Our ancestors lifted rocks, carried game, climbed trees, and built shelters.

Our "Greasing the Groove" system sends you strength exercises throughout the day—push-ups, squats, planks, and more.

Short bursts of effort, never to failure. This builds real, functional strength without the burnout.''',
    ),
    _OnboardingPage(
      icon: Icons.directions_run,
      title: '4. Run Really Fast',
      subtitle: 'Once in a While',
      body:
          '''Sometimes our ancestors had to sprint—chasing prey or escaping predators.

That's why we schedule 2 Sprint Sessions per month, at least 7 days apart. You'll get a notification on sprint days.

Just a few all-out sprints. Brief, intense, and incredibly effective for fitness and fat burning.''',
    ),
    _OnboardingPage(
      icon: Icons.bedtime,
      title: '5. Get Lots of Sleep',
      subtitle: 'Recovery Is Non-Negotiable',
      body:
          '''Our ancestors slept when it got dark and rose with the sun. 7-9 hours of quality sleep was the norm.

While we can't track your sleep, remember: this is when your body repairs and grows stronger.

Prioritize sleep. Your exercise "snacks" will feel easier when you're well-rested.''',
    ),
    _OnboardingPage(
      icon: Icons.sports_esports,
      title: '6. Play',
      subtitle: 'Have Fun Moving',
      body:
          '''Our ancestors played—wrestling, games, exploration. Movement was joyful, not a chore.

That's why our exercises are varied and our reminders are random. Each notification is a mini-adventure.

Don't take it too seriously. Enjoy the movement. Play with your kids. Dance. Have fun.''',
    ),
    _OnboardingPage(
      icon: Icons.wb_sunny,
      title: '7. Get Sunlight',
      subtitle: 'Every Day',
      body:
          '''Our ancestors lived outdoors. Sunlight regulated their hormones, vitamin D levels, and circadian rhythms.

Your daily walk is the perfect opportunity to get outside and soak up some rays.

Morning sunlight is especially powerful. Take your walk outside when you can.''',
    ),
    _OnboardingPage(
      icon: Icons.healing,
      title: '8. Avoid Trauma',
      subtitle: 'Train Smart, Stay Healthy',
      body:
          '''Our ancestors avoided unnecessary risks. An injury could mean death.

That's why we use "Greasing the Groove"—never training to failure, always staying fresh. Progressive overload is gradual (+2 reps when it feels easy).

Listen to your body. Skip a session if you need to. Long-term consistency beats short-term intensity.''',
    ),
    _OnboardingPage(
      icon: Icons.block,
      title: '9. Avoid Poison',
      subtitle: 'Protect Your Body',
      body: '''Our ancestors knew which plants and substances to avoid.

Today's "poisons" are processed foods, excess sugar, seed oils, chronic stress, and too much screen time.

Use this app mindfully. Do your exercises, take your walks, then put the phone down and live your life.''',
    ),
    _OnboardingPage(
      icon: Icons.psychology,
      title: '10. Use Your Mind',
      subtitle: 'Stay Curious & Creative',
      body:
          '''Our ancestors solved problems, told stories, and explored their world.

Physical fitness supports mental fitness. Exercise improves focus, creativity, and mood.

Challenge yourself. Learn new movements. Pay attention to how exercises feel. The mind-body connection is real.

Ready to live primally?''',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onComplete();
    }
  }

  void _skip() {
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button (top right)
            if (!isLastPage)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _skip,
                    child: Text(
                      'Skip',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 56),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicator dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: _nextPage,
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isLastPage ? "LET'S GO" : 'NEXT',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),

          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            page.subtitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Body text
          Text(
            page.body,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;
  final String body;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.body,
  });
}
