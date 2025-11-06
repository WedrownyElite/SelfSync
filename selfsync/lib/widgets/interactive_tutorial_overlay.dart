import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// Onboarding overlay that guides users through app features
class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;
  final void Function(int stepIndex)? onStepChanged;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
    this.onStepChanged,
  });

  @override
  State<OnboardingOverlay> createState() => OnboardingOverlayState();
}

class OnboardingOverlayState extends State<OnboardingOverlay>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _currentStep = 0;
  bool _isStepDelayed = false; // New: flag to delay rendering
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isKeyboardVisible = false;
  late AnimationController _cardAnimationController;
  late Animation<double> _cardScaleAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AppLogger.info('Onboarding started', tag: 'Onboarding');

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    // Card animation controller
    _cardAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _cardScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _cardAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardAnimationController.forward();
    _logStep();
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    final bottomInset = WidgetsBinding.instance.platformDispatcher.views.first.viewInsets.bottom;
    final keyboardVisible = bottomInset > 0;

    if (keyboardVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = keyboardVisible;
      });
      AppLogger.debug('Keyboard visibility changed: $keyboardVisible', tag: 'Onboarding');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  void _logStep() {
    final step = widget.steps[_currentStep];
    AppLogger.separator(label: 'STEP ${_currentStep + 1}/${widget.steps.length}');
    AppLogger.info('Title: ${step.title}', tag: 'Onboarding');
    AppLogger.info('Interactive: ${step.requiresAction}', tag: 'Onboarding');
    AppLogger.separator();
  }

  /// Progress to next step - called externally or internally
  void nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      HapticFeedback.lightImpact();

      final nextStepIndex = _currentStep + 1;

// Special handling for steps that scroll FIRST, then spotlight
// Trends: 14, 16, 18
// Settings: 27 only (25 and 26 don't scroll)
      if (nextStepIndex == 14 || nextStepIndex == 16 || nextStepIndex == 18 ||
          nextStepIndex == 27) {
        // Set delay flag to hide the overlay
        setState(() {
          _isStepDelayed = true;
          _currentStep = nextStepIndex;
        });

        _logStep();
        widget.onStepChanged?.call(_currentStep);

        // After 1100ms, show the step
        Future.delayed(const Duration(milliseconds: 1100), () {
          if (mounted) {
            setState(() {
              _isStepDelayed = false;
            });
            // Restart card animation
            _cardAnimationController.reset();
            _cardAnimationController.forward();
          }
        });
      } else if (nextStepIndex == 15 || nextStepIndex == 17 || nextStepIndex == 19 ||
          nextStepIndex == 25 || nextStepIndex == 26) {
        // Steps with short delay, no scroll (same Y level as previous)
        setState(() {
          _isStepDelayed = true;
          _currentStep = nextStepIndex;
        });

        _logStep();
        widget.onStepChanged?.call(_currentStep);

        // After 300ms, show the step
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {
              _isStepDelayed = false;
            });
            // Restart card animation
            _cardAnimationController.reset();
            _cardAnimationController.forward();
          }
        });
      } else {
        // Normal step progression
        setState(() => _currentStep = nextStepIndex);
        _logStep();
        widget.onStepChanged?.call(_currentStep);

        // Restart card animation for new step
        _cardAnimationController.reset();
        _cardAnimationController.forward();
      }
    } else {
      AppLogger.success('Onboarding completed', tag: 'Onboarding');
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final theme = Theme.of(context);

    // If step is delayed, don't render anything
    if (_isStepDelayed) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        // Dark overlay for non-interactive steps (only if showOverlay is true)
        if (!step.requiresAction && step.showOverlay)
          Positioned.fill(
            child: GestureDetector(
              onTap: nextStep,
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),

        // Highlight spotlight
        if (step.targetKey != null && !_isKeyboardVisible)
          _buildSpotlight(step.targetKey!),

        // Instruction card
        _buildInstructionCard(theme, step),

        // Skip button
        if (widget.onSkip != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: TextButton(
              onPressed: widget.onSkip,
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpotlight(GlobalKey targetKey) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    AppLogger.debug('Spotlight position: $position, size: $size', tag: 'Onboarding');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final padding = 16.0 * _pulseAnimation.value;

        return Positioned(
          left: position.dx - padding,
          top: position.dy - padding,
          child: IgnorePointer(
            child: Container(
              width: size.width + (padding * 2),
              height: size.height + (padding * 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.greenAccent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.greenAccent.withValues(alpha: 0.5),
                    blurRadius: 20 * _pulseAnimation.value,
                    spreadRadius: 5 * _pulseAnimation.value,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstructionCard(ThemeData theme, OnboardingStep step) {
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;

    double? topPosition;
    double? bottomPosition;

    // Center card if requested
    if (step.centerCard) {
      topPosition = null;
      bottomPosition = null;
      AppLogger.debug('Card positioned at CENTER', tag: 'Onboarding');
    }
    // Force top position if specified or keyboard is visible
    else if (step.forceTopPosition || _isKeyboardVisible) {
      topPosition = MediaQuery.of(context).padding.top + 16;
      AppLogger.debug('Card positioned at TOP (forced or keyboard)', tag: 'Onboarding');
    } else if (step.targetKey != null) {
      final renderBox = step.targetKey!.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final targetCenter = position.dy + (size.height / 2);

        if (targetCenter > availableHeight / 2) {
          topPosition = MediaQuery.of(context).padding.top + 80;
          AppLogger.debug('Card positioned at TOP', tag: 'Onboarding');
        } else {
          bottomPosition = MediaQuery.of(context).padding.bottom + 16;
          AppLogger.debug('Card positioned at BOTTOM', tag: 'Onboarding');
        }
      } else {
        bottomPosition = MediaQuery.of(context).padding.bottom + 16;
        AppLogger.debug('Card positioned at BOTTOM (no target)', tag: 'Onboarding');
      }
    } else {
      bottomPosition = MediaQuery.of(context).padding.bottom + 16;
      AppLogger.debug('Card positioned at BOTTOM (no target)', tag: 'Onboarding');
    }

    // Use Center widget if centering, otherwise use Positioned
    if (step.centerCard) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildCardContent(theme, step),
        ),
      );
    }

    return Positioned(
      top: topPosition,
      bottom: bottomPosition,
      left: 16,
      right: 16,
      child: _buildCardContent(theme, step),
    );
  }

  Widget _buildCardContent(ThemeData theme, OnboardingStep step) {
    return AnimatedBuilder(
      animation: _cardAnimationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _cardScaleAnimation.value,
          child: Opacity(
            opacity: _cardFadeAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: !step.requiresAction ? nextStep : null,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primaryContainer,
                  theme.colorScheme.secondaryContainer,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Step indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Step ${_currentStep + 1} of ${widget.steps.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    step.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    step.description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.9),
                      height: 1.4,
                    ),
                  ),

                  // Action hint
                  if (step.actionHint != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          step.requiresAction ? Icons.touch_app : Icons.tap_and_play,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            step.actionHint!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Tap to continue (non-interactive only)
                  if (!step.requiresAction) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        step.showOverlay ? 'Tap anywhere to continue' : 'Tap to continue',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final String? actionHint;
  final GlobalKey? targetKey;
  final bool requiresAction;
  final bool forceTopPosition;
  final bool showOverlay;
  final bool centerCard;

  const OnboardingStep({
    required this.title,
    required this.description,
    this.actionHint,
    this.targetKey,
    this.requiresAction = false,
    this.forceTopPosition = false,
    this.showOverlay = true,
    this.centerCard = false,
  });
}

/// Global controller for onboarding
class OnboardingController {
  static OverlayEntry? _entry;
  static final _stateKey = GlobalKey<OnboardingOverlayState>();

  static void start(
      BuildContext context, {
        required List<OnboardingStep> steps,
        required VoidCallback onComplete,
        VoidCallback? onSkip,
        void Function(int stepIndex)? onStepChanged,
      }) {
    hide();

    _entry = OverlayEntry(
      builder: (context) {
        return OnboardingOverlay(
          key: _stateKey,
          steps: steps,
          onComplete: () {
            hide();
            onComplete();
          },
          onSkip: onSkip != null
              ? () {
            hide();
            onSkip();
          }
              : null,
          onStepChanged: onStepChanged,
        );
      },
    );

    Overlay.of(context).insert(_entry!);
    AppLogger.success('Onboarding overlay inserted', tag: 'Onboarding');
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static void nextStep() {
    final state = _stateKey.currentState;
    if (state != null && state.mounted) {
      AppLogger.info('Progressing to next step', tag: 'Onboarding');
      state.nextStep();
    } else {
      AppLogger.warning('Cannot progress - state not available yet', tag: 'Onboarding');
      Future.delayed(const Duration(milliseconds: 50), () {
        final retryState = _stateKey.currentState;
        if (retryState != null && retryState.mounted) {
          AppLogger.info('Retry successful - progressing', tag: 'Onboarding');
          retryState.nextStep();
        } else {
          AppLogger.error('State still not available after retry', tag: 'Onboarding');
        }
      });
    }
  }
}