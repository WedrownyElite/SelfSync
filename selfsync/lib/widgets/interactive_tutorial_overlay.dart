import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_logger.dart';

/// TRUE interactive tutorial - user must actually USE the app to proceed
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
    AppLogger.lifecycle('Tutorial overlay initialized', tag: 'Tutorial');

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

    AppLogger.info('Starting with step 0', tag: 'Tutorial');
    _logCurrentStepInfo();
  }

  void _logCurrentStepInfo() {
    final step = widget.steps[_currentStep];
    AppLogger.separator(label: 'TUTORIAL STEP ${_currentStep + 1}/${widget.steps.length}');
    AppLogger.info('Title: ${step.title}', tag: 'Tutorial');
    AppLogger.info('Requires interaction: ${step.requiresInteraction}', tag: 'Tutorial');
    AppLogger.info('Has target: ${step.targetKey != null}', tag: 'Tutorial');
    AppLogger.separator();
  }

  @override
  void dispose() {
    AppLogger.lifecycle('Tutorial overlay disposed', tag: 'Tutorial');
    _pulseController.dispose();
    super.dispose();
  }

  void _handleStepProgress() {
    if (_waitingForAction) {
      AppLogger.warning('Step progression blocked - already waiting', tag: 'Tutorial');
      return;
    }

    AppLogger.info('Progressing from step ${_currentStep + 1}', tag: 'Tutorial');

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
          AppLogger.success('Advanced to step ${_currentStep + 1}', tag: 'Tutorial');
          _logCurrentStepInfo();
        }
      });
    } else {
      AppLogger.success('Tutorial completed!', tag: 'Tutorial');
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentStep];
    final theme = Theme.of(context);

    AppLogger.debug('Building tutorial overlay for step ${_currentStep + 1}', tag: 'Tutorial');
    AppLogger.debug('Step requires interaction: ${step.requiresInteraction}', tag: 'Tutorial');

    if (step.requiresInteraction) {
      AppLogger.info('INTERACTIVE MODE - No touch blocking', tag: 'Tutorial');
      return _buildInteractiveMode(context, theme, step);
    } else {
      AppLogger.info('NON-INTERACTIVE MODE - Dark overlay with tap to continue', tag: 'Tutorial');
      return _buildNonInteractiveMode(context, theme, step);
    }
  }

  // Interactive mode: Completely transparent to touches - NO blocking
  Widget _buildInteractiveMode(BuildContext context, ThemeData theme, InteractiveTutorialStep step) {
    return Stack(
      children: [
        // Pulsing spotlight - wrapped in IgnorePointer so it doesn't block
        if (step.targetKey != null)
          IgnorePointer(
            child: _buildPulsingSpotlight(step.targetKey!, theme),
          ),

        // Instruction card - wrapped in IgnorePointer so it doesn't block
        _buildSmartInstructionCard(theme, step, interactive: true),

        // Skip button (ALWAYS tappable) - NOT wrapped, Positioned is direct child
        if (widget.onSkip != null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: TextButton(
              onPressed: () {
                AppLogger.info('Skip button pressed', tag: 'Tutorial');
                widget.onSkip!();
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
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

        // Debug indicator - FIXED: Positioned is direct child, IgnorePointer wraps contents
        Positioned(
          top: MediaQuery.of(context).padding.top + 50,
          left: 0,
          right: 0,
          child: IgnorePointer(
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '✓ INTERACTIVE - SCREEN IS TAPPABLE',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Non-interactive mode: Full dark overlay
  Widget _buildNonInteractiveMode(BuildContext context, ThemeData theme, InteractiveTutorialStep step) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Full dark overlay
          GestureDetector(
            onTap: () {
              AppLogger.info('Dark overlay tapped - progressing step', tag: 'Tutorial');
              _handleStepProgress();
            },
            child: Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ),

          // Instruction card
          _buildSmartInstructionCard(theme, step, interactive: false),

          // Skip button - Positioned is direct child
          if (widget.onSkip != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: TextButton(
                onPressed: () {
                  AppLogger.info('Skip button pressed', tag: 'Tutorial');
                  widget.onSkip!();
                },
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

  Widget _buildPulsingSpotlight(GlobalKey targetKey, ThemeData theme) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      AppLogger.warning('Target widget not found for spotlight', tag: 'Tutorial');
      return const SizedBox.shrink();
    }

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    AppLogger.debug('Spotlight position: $position, size: $size', tag: 'Tutorial');

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final padding = 12.0 * _pulseAnimation.value;

        return Stack(
          children: [
            // Green border highlight
            Positioned(
              left: position.dx - padding,
              top: position.dy - padding,
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

  // CRITICAL FIX: Positioned must be DIRECT child of Stack, wrap contents with IgnorePointer instead
  Widget _buildSmartInstructionCard(ThemeData theme, InteractiveTutorialStep step, {required bool interactive}) {
    final renderBox = step.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final screenHeight = MediaQuery.of(context).size.height;

    double? topPosition;
    double? bottomPosition;

    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final targetCenter = position.dy + (size.height / 2);

      if (targetCenter > screenHeight / 2) {
        topPosition = MediaQuery.of(context).padding.top + 80;
        AppLogger.debug('Card positioned at TOP', tag: 'Tutorial');
      } else {
        bottomPosition = MediaQuery.of(context).padding.bottom + 16;
        AppLogger.debug('Card positioned at BOTTOM', tag: 'Tutorial');
      }
    } else {
      bottomPosition = MediaQuery.of(context).padding.bottom + 16;
      AppLogger.debug('Card positioned at BOTTOM (no target)', tag: 'Tutorial');
    }

    // Positioned MUST be direct child of Stack
    return Positioned(
      top: topPosition,
      bottom: bottomPosition,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: interactive, // Block pointer events ONLY for interactive mode
        child: GestureDetector(
          onTap: interactive ? null : () {
            AppLogger.info('Instruction card tapped - progressing step', tag: 'Tutorial');
            _handleStepProgress();
          },
          child: Container(
            constraints: const BoxConstraints(
              maxHeight: 180,
            ),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
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
  final bool requiresInteraction;

  const InteractiveTutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
    this.actionInstruction,
    this.requiresInteraction = false,
  });
}

class InteractiveTutorialController {
  static OverlayEntry? _overlayEntry;
  static _InteractiveTutorialOverlayState? _currentState;

  static void show(
      BuildContext context, {
        required List<InteractiveTutorialStep> steps,
        required VoidCallback onComplete,
        VoidCallback? onSkip,
      }) {
    AppLogger.lifecycle('Showing tutorial overlay', tag: 'Tutorial');
    hide();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        AppLogger.debug('Building overlay entry', tag: 'Tutorial');
        final overlay = InteractiveTutorialOverlay(
          steps: steps,
          onComplete: () {
            AppLogger.success('Tutorial completed callback fired', tag: 'Tutorial');
            hide();
            onComplete();
          },
          onSkip: onSkip != null
              ? () {
            AppLogger.info('Tutorial skipped callback fired', tag: 'Tutorial');
            hide();
            onSkip();
          }
              : null,
        );

        return overlay;
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    AppLogger.success('Tutorial overlay inserted into overlay stack', tag: 'Tutorial');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppLogger.debug('Attempting to get state reference...', tag: 'Tutorial');
      final overlayContext = _overlayEntry?.mounted == true ? Overlay.of(context).context : null;
      if (overlayContext != null) {
        _currentState = overlayContext.findAncestorStateOfType<_InteractiveTutorialOverlayState>();
        if (_currentState != null) {
          AppLogger.success('State reference obtained', tag: 'Tutorial');
        } else {
          AppLogger.warning('State reference is null', tag: 'Tutorial');
        }
      } else {
        AppLogger.warning('Overlay context is null', tag: 'Tutorial');
      }
    });
  }

  static void hide() {
    if (_overlayEntry != null) {
      AppLogger.info('Hiding tutorial overlay', tag: 'Tutorial');
      _overlayEntry?.remove();
      _overlayEntry = null;
      _currentState = null;
    }
  }

  static void completeCurrentStep() {
    if (_currentState != null) {
      AppLogger.info('External step completion requested', tag: 'Tutorial');
      _currentState?._handleStepProgress();
    } else {
      AppLogger.warning('Cannot complete step - state reference is null', tag: 'Tutorial');
    }
  }
}