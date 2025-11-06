import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

/// Privacy policy acceptance dialog shown on first app launch
class PrivacyPolicyDialog extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback? onDecline;

  const PrivacyPolicyDialog({
    super.key,
    required this.onAccept,
    this.onDecline,
  });

  @override
  State<PrivacyPolicyDialog> createState() => _PrivacyPolicyDialogState();
}

class _PrivacyPolicyDialogState extends State<PrivacyPolicyDialog>
    with TickerProviderStateMixin {
  bool _hasScrolledToBottom = false;
  bool _userHasScrolled = false;
  final ScrollController _scrollController = ScrollController();
  late AnimationController _animationController;
  late AnimationController _scrollHintController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scrollHintOpacity;
  late Animation<Offset> _scrollHintSlide;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scrollHintController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Scroll hint animations
    _scrollHintOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_scrollHintController);

    _scrollHintSlide = TweenSequence<Offset>([
      TweenSequenceItem(
        tween: Tween(begin: Offset.zero, end: const Offset(0, 0.15)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: const Offset(0, 0.15), end: Offset.zero),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _scrollHintController,
        curve: Curves.easeInOut,
      ),
    );

    _scrollController.addListener(_onScroll);
    _animationController.forward();

    // Start scroll hint animation after dialog appears
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && !_userHasScrolled) {
        _scrollHintController.repeat();
      }
    });
  }

  void _onScroll() {
    // User has manually scrolled
    if (!_userHasScrolled) {
      setState(() {
        _userHasScrolled = true;
      });
      // Fade out the scroll hint
      _scrollHintController.stop();
      _scrollHintController.animateTo(1.0, duration: const Duration(milliseconds: 300));
    }

    if (!_hasScrolledToBottom &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50) {
      setState(() {
        _hasScrolledToBottom = true;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _animationController.dispose();
    _scrollHintController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _handleDecline() {
    // Show exit confirmation dialog
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text(
          'You must accept the Privacy Policy and Terms of Service to use Self Sync.\n\nWould you like to exit the app?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Go Back'),
          ),
          FilledButton(
            onPressed: () {
              // Close dialog
              Navigator.pop(dialogContext);
              // Call onDecline callback
              widget.onDecline?.call();
              // Exit the app
              exit(0);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Exit App'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Prevent dismissal by back button
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleDecline();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 600,
                maxHeight: 700,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(28),
                          topRight: Radius.circular(28),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.privacy_tip_rounded,
                            size: 56,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Welcome to Self Sync',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your personal mood tracking companion',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    // Content with scroll hint
                    Flexible(
                      child: Stack(
                        children: [
                          SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Privacy & Terms',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                _buildSection(
                                  theme: theme,
                                  icon: Icons.lock_rounded,
                                  title: 'Your Data is Private',
                                  description: 'All your mood entries and personal information stay on your device. We never upload, share, or sell your data.',
                                ),

                                const SizedBox(height: 16),

                                _buildSection(
                                  theme: theme,
                                  icon: Icons.phone_android_rounded,
                                  title: 'Local Storage Only',
                                  description: 'Everything you track remains stored locally on your device. You have complete control over your information.',
                                ),

                                const SizedBox(height: 16),

                                _buildSection(
                                  theme: theme,
                                  icon: Icons.analytics_outlined,
                                  title: 'Anonymous Analytics',
                                  description: 'We collect anonymous usage statistics to improve the app. No personal information or mood data is included. You can disable this in settings.',
                                ),

                                const SizedBox(height: 24),

                                // Links
                                RichText(
                                  text: TextSpan(
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      height: 1.5,
                                    ),
                                    children: [
                                      const TextSpan(
                                        text: 'By continuing, you agree to our ',
                                      ),
                                      TextSpan(
                                        text: 'Privacy Policy',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _launchURL('https://oddologyinc.com/privacy'),
                                      ),
                                      const TextSpan(text: ' and '),
                                      TextSpan(
                                        text: 'Terms of Service',
                                        style: TextStyle(
                                          color: theme.colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => _launchURL('https://oddologyinc.com/terms'),
                                      ),
                                      const TextSpan(text: '.'),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 16),
                              ],
                            ),
                          ),

                          // Animated scroll hint - only show if user hasn't scrolled
                          if (!_userHasScrolled && !_hasScrolledToBottom)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: FadeTransition(
                                  opacity: _scrollHintOpacity,
                                  child: SlideTransition(
                                    position: _scrollHintSlide,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            theme.colorScheme.surface.withValues(alpha: 0.0),
                                            theme.colorScheme.surface.withValues(alpha: 0.95),
                                            theme.colorScheme.surface,
                                          ],
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.swipe_up_rounded,
                                            size: 32,
                                            color: theme.colorScheme.primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Scroll to continue',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              color: theme.colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          // Static scroll indicator (after user scrolls but hasn't reached bottom)
                          if (_userHasScrolled && !_hasScrolledToBottom)
                            Positioned(
                              bottom: 8,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.9),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: 16,
                                          color: theme.colorScheme.onPrimaryContainer,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Scroll to continue',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: theme.colorScheme.onPrimaryContainer,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _hasScrolledToBottom ? widget.onAccept : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                'Accept & Continue',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _hasScrolledToBottom
                                      ? Colors.white
                                      : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton(
                              onPressed: _handleDecline,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: Text(
                                'Decline & Exit',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PrivacyPolicyController {
  static Future<bool?> show(
      BuildContext context, {
        required VoidCallback onAccept,
        VoidCallback? onDecline,
      }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PrivacyPolicyDialog(
        onAccept: () {
          Navigator.of(context).pop(true);
          onAccept();
        },
        onDecline: onDecline != null
            ? () {
          Navigator.of(context).pop(false);
          onDecline();
        }
            : null,
      ),
    );
  }
}