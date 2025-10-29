import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

/// Interactive tutorial overlay that shows step-by-step guidance
class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;
  final VoidCallback? onSkip;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
    this.onSkip,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.steps.length - 1) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentStep++;
        });
        _animationController.forward();
        HapticFeedback.lightImpact();
      });
    } else {
      _complete();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _animationController.reverse().then((_) {
        setState(() {
          _currentStep--;
        });
        _animationController.forward();
        HapticFeedback.lightImpact();
      });
    }
  }

  void _complete() {
    HapticFeedback.mediumImpact();
    widget.onComplete();
  }

  void _skip() {
    HapticFeedback.lightImpact();
    if (widget.onSkip != null) {
      widget.onSkip!();
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
          // Backdrop with blur
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.withValues(alpha: 0.7),
            ),
          ),

          // Highlighted area (spotlight effect)
          if (step.targetKey != null)
            _buildSpotlight(step.targetKey!),

          // Tutorial content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: _buildTutorialContent(theme, step),
                ),
              );
            },
          ),

          // Navigation controls
          _buildNavigationControls(theme),

          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: _skip,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildSpotlight(GlobalKey targetKey) {
    final renderBox = targetKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Positioned(
      left: position.dx - 8,
      top: position.dy - 8,
      child: Container(
        width: size.width + 16,
        height: size.height + 16,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTutorialContent(ThemeData theme, TutorialStep step) {
    final renderBox = step.targetKey?.currentContext?.findRenderObject() as RenderBox?;
    final screenSize = MediaQuery.of(context).size;

    // Default position if no target
    Alignment alignment = Alignment.center;
    EdgeInsets margin = const EdgeInsets.all(32);

    if (renderBox != null) {
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final targetCenter = position.dy + size.height / 2;
      final screenCenter = screenSize.height / 2;

      // Position tooltip above or below target based on space
      if (targetCenter < screenCenter) {
        // Target in top half - show tooltip below
        alignment = Alignment.topCenter;
        margin = EdgeInsets.only(
          top: position.dy + size.height + 24,
          left: 24,
          right: 24,
        );
      } else {
        // Target in bottom half - show tooltip above
        alignment = Alignment.bottomCenter;
        margin = EdgeInsets.only(
          bottom: screenSize.height - position.dy + 24,
          left: 24,
          right: 24,
        );
      }
    }

    return Align(
      alignment: alignment,
      child: Container(
        margin: margin,
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
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
                // Icon
                if (step.icon != null) ...[
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      step.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Title
                Text(
                  step.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // Description
                Text(
                  step.description,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),

                // Progress indicator
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.steps.length, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentStep == index ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentStep == index
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationControls(ThemeData theme) {
    final isFirstStep = _currentStep == 0;
    final isLastStep = _currentStep == widget.steps.length - 1;

    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Back button
            if (!isFirstStep)
              IconButton(
                onPressed: _previousStep,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  padding: const EdgeInsets.all(16),
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              )
            else
              const SizedBox(width: 56),

            // Next/Done button
            ElevatedButton(
              onPressed: _nextStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isLastStep ? 'Got it!' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLastStep ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Represents a single step in the tutorial
class TutorialStep {
  final String title;
  final String description;
  final IconData? icon;
  final GlobalKey? targetKey;

  const TutorialStep({
    required this.title,
    required this.description,
    this.icon,
    this.targetKey,
  });
}

/// Controller to show tutorial overlay
class TutorialController {
  static OverlayEntry? _overlayEntry;

  /// Show tutorial overlay
  static void show(
      BuildContext context, {
        required List<TutorialStep> steps,
        required VoidCallback onComplete,
        VoidCallback? onSkip,
      }) {
    hide(); // Remove any existing overlay

    _overlayEntry = OverlayEntry(
      builder: (context) => TutorialOverlay(
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

  /// Hide tutorial overlay
  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}