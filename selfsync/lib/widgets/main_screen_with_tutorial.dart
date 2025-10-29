import 'package:flutter/material.dart';
import '../services/onboarding_service.dart';
import '../services/analytics_service.dart';
import '../widgets/tutorial_overlay.dart';

/// Wrapper that shows tutorial after first launch
class MainScreenWithTutorial extends StatefulWidget {
  final Widget child;
  final OnboardingService onboardingService;
  final AnalyticsService analyticsService;
  final List<TutorialStep> tutorialSteps;

  const MainScreenWithTutorial({
    super.key,
    required this.child,
    required this.onboardingService,
    required this.analyticsService,
    required this.tutorialSteps,
  });

  @override
  State<MainScreenWithTutorial> createState() => _MainScreenWithTutorialState();
}

class _MainScreenWithTutorialState extends State<MainScreenWithTutorial> {
  @override
  void initState() {
    super.initState();

    // Show tutorial after first frame if needed
    if (widget.onboardingService.shouldShowTutorial) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showTutorial();
      });
    }
  }

  void _showTutorial() {
    widget.analyticsService.trackEvent('tutorial_started');

    TutorialController.show(
      context,
      steps: widget.tutorialSteps,
      onComplete: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_completed');
      },
      onSkip: () async {
        await widget.onboardingService.completeTutorial();
        widget.analyticsService.trackEvent('tutorial_skipped');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}