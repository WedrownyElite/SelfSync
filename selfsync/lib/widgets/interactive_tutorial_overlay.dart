import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TRUE interactive tutorial - user must actually USE the app to proceed
/// Detects actual taps on target elements and positions instruction card smartly
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
  bool _waitingForAction = false;

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

  void _handleStepProgress() {
    if (_waitingForAction) return; // Prevent double progression

    setState(() {
      _waitingForAction = true;
    });

    HapticFeedback.mediumImpact();

    if (_currentStep < widget.steps.length - 1) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentStep++;
            _waitingForAction = false;
          });
        }
      });
    } else {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent overlay WITH CUTOUT for target (allows interaction)
          if (step.targetKey != null && step.requiresInteraction)
            _buildOverlayWithCutout(step.targetKey!)
          else
          // Full overlay for non-interactive steps
            GestureDetector(
              onTap: _handleStepProgress,
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),

          // Pulsing spotlight on target
          if (step.targetKey != null)
            _buildPulsingSpotlight(step.targetKey!, theme, step.requiresInteraction),

          // Instruction card (positioned smartly to avoid blocking targets)
          _buildSmartInstructionCard(theme, step),

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
    );
  }

  // Create overlay with hole cut out for target
  Widget _buildOverlayWithCutout(GlobalKey targetKey) {
    return CustomPaint(
      painter: _OverlayCutoutPainter(
        targetKey: targetKey,
        animation: _pulseAnimation,
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Tapping outside the cutout does nothing (only target tap progresses)
        },
        child: Container(),
      ),
    );
  }

  Widget _buildPulsingSpotlight(GlobalKey targetKey, ThemeData theme, bool allowInteraction) {
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
            // Invisible tap detector for interactive targets
            if (allowInteraction)
              Positioned(
                left: position.dx - padding,
                top: position.dy - padding,
                child: GestureDetector(
                  onTap: _handleStepProgress,
                  child: Container(
                    width: size.width + (padding * 2),
                    height: size.height + (padding * 2),
                    color: Colors.transparent,
                  ),
                ),
              ),

            // Green border highlight
            Positioned(
              left: position.dx - padding,
              top: position.dy - padding,
              child: IgnorePointer(
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
              child: IgnorePointer(
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmartInstructionCard(ThemeData theme, InteractiveTutorialStep step) {
    // Calculate smart positioning based on target location
    final renderBox = step.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final screenHeight = MediaQuery.of(context).size.height;

    // Determine position - use ONLY ONE anchor point
    double? topPosition;
    double? bottomPosition;

    // If we have a target, position the card intelligently
    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final targetBottom = position.dy + size.height;
      final targetCenter = position.dy + (size.height / 2);

      // If target is in bottom half, show card at top
      if (targetCenter > screenHeight / 2) {
        topPosition = MediaQuery.of(context).padding.top + 80; // Below skip button
      }
      // If target is in top half but card would overlap, show above target
      else if (targetBottom > screenHeight - 220) {
        bottomPosition = screenHeight - position.dy + 16;
      }
      // Otherwise default to bottom
      else {
        bottomPosition = MediaQuery.of(context).padding.bottom + 16;
      }
    } else {
      // No target, default to bottom
      bottomPosition = MediaQuery.of(context).padding.bottom + 16;
    }

    return Positioned(
      top: topPosition, // EITHER this is set
      bottom: bottomPosition, // OR this is set (NOT BOTH!)
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: step.requiresInteraction ? null : _handleStepProgress,
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 180, // LIMIT HEIGHT
          ),
          padding: const EdgeInsets.all(16), // REDUCED from 20
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16), // REDUCED from 20
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: SingleChildScrollView( // ALLOW SCROLLING if needed
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator - COMPACT
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Step ${_currentStep + 1}/${widget.steps.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Title - COMPACT
                Text(
                  step.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Description - COMPACT
                Text(
                  step.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.3,
                    fontSize: 13,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Action hint - COMPACT
                if (step.actionInstruction != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        step.requiresInteraction ? Icons.touch_app_rounded : Icons.tap_and_play_rounded,
                        color: Colors.greenAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.actionInstruction!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.greenAccent[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
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
  final bool requiresInteraction; // Whether user MUST tap the target to proceed

  const InteractiveTutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
    this.actionInstruction,
    this.requiresInteraction = false, // Default to false (tap anywhere works)
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

/// Custom painter that draws overlay with a hole cut out for the target
class _OverlayCutoutPainter extends CustomPainter {
  final GlobalKey targetKey;
  final Animation<double> animation;

  _OverlayCutoutPainter({
    required this.targetKey,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      // No target, just draw full overlay
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.black.withValues(alpha: 0.5),
      );
      return;
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final padding = 12.0 * animation.value;

    // Create path for the overlay with hole
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Create rounded rect for the cutout (slightly larger than target for padding)
    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        position.dx - padding,
        position.dy - padding,
        targetSize.width + (padding * 2),
        targetSize.height + (padding * 2),
      ),
      const Radius.circular(16),
    );

    // Subtract the cutout from overlay
    overlayPath.addRRect(cutoutRect);
    overlayPath.fillType = PathFillType.evenOdd;

    // Draw overlay with hole
    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_OverlayCutoutPainter oldDelegate) {
    return true; // Repaint on animation
  }
}