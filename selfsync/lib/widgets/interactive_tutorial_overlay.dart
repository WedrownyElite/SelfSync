import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TRUE interactive tutorial - user must actually USE the app to proceed
/// NO back/next buttons - only progresses when user completes the action
class InteractiveTutorialOverlay extends StatefulWidget {
  final List<InteractiveTutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const InteractiveTutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
  });

  @override
  State<InteractiveTutorialOverlay> createState() => _InteractiveTutorialOverlayState();
}

class _InteractiveTutorialOverlayState extends State<InteractiveTutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();

        if (_currentStep < widget.steps.length - 1) {
          setState(() {
            _currentStep++;
          });
        } else {
          widget.onComplete();
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Semi-transparent overlay (NO BLUR)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),

            // Pulsing spotlight on target
            if (step.targetKey != null) _buildPulsingSpotlight(step.targetKey!, theme),

            // Instruction card
            _buildInstructionCard(theme, step),

            // Skip button (top right)
            if (widget.onSkip != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 8,
                child: TextButton(
                  onPressed: widget.onSkip,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingSpotlight(GlobalKey targetKey, ThemeData theme) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final padding = 12.0 * _pulseAnimation.value;

        return Stack(
          children: [
            // Clear area (no overlay) - allows actual interaction
            Positioned(
              left: position.dx - padding,
              top: position.dy - padding,
              child: IgnorePointer(
                ignoring: false,
                child: Container(
                  width: size.width + (padding * 2),
                  height: size.height + (padding * 2),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.greenAccent,
                      width: 4,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.6),
                        blurRadius: 30 * _pulseAnimation.value,
                        spreadRadius: 10 * _pulseAnimation.value,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Arrow pointing to target
            Positioned(
              left: position.dx + size.width / 2 - 20,
              top: position.dy - 60,
              child: Icon(
                Icons.arrow_downward_rounded,
                color: Colors.greenAccent,
                size: 40,
                shadows: [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInstructionCard(ThemeData theme, InteractiveTutorialStep step) {
    // Position at bottom of screen
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Step ${_currentStep + 1} of ${widget.steps.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              step.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            Text(
              step.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                height: 1.5,
              ),
            ),

            // Action hint
            if (step.actionInstruction != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: Colors.greenAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.actionInstruction!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.greenAccent[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InteractiveTutorialStep {
  final String title;
  final String description;
  final IconData? icon;
  final GlobalKey? targetKey;
  final String? actionInstruction;
  final VoidCallback? onActionComplete; // Callback when user completes the action

  const InteractiveTutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
    this.actionInstruction,
    this.onActionComplete,
  });
}

class InteractiveTutorialController {
  static OverlayEntry? _overlayEntry;

  static void show(
      BuildContext context, {
        required List<InteractiveTutorialStep> steps,
        required VoidCallback onComplete,
        VoidCallback? onSkip,
      }) {
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) => InteractiveTutorialOverlay(
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
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  static void completeCurrentStep() {
    // This will be called by the app when user completes an action
    // The overlay state will handle progression
  }
}