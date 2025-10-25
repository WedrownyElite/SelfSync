// ignore_for_file: avoid_print
import 'package:flutter/material.dart';
import '../utils/app_logger.dart';
import '../screens/help_screen.dart';

/// A custom side drawer that slides in from the left side of the screen
/// Occupies 1/4 of screen width with smooth animation
class SideDrawer extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onDiaryTap;
  final VoidCallback? onTrendsTap;

  const SideDrawer({
    super.key,
    required this.onClose,
    this.onSettingsTap,
    this.onCalendarTap,
    this.onDiaryTap,
    this.onTrendsTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Use a minimum width to prevent overflow on narrow screens
    final drawerWidth = screenWidth < 400
        ? screenWidth * 0.7 // 70% on very small screens
        : screenWidth < 600
        ? screenWidth * 0.5 // 50% on small screens
        : screenWidth * 0.25; // 25% on larger screens

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        constraints: const BoxConstraints(
          minWidth: 200, // Minimum width to prevent overflow
          maxWidth: 400, // Maximum width for very large screens
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with close button
              _buildHeader(theme),

              const Divider(height: 1),

              // Drawer content
              Expanded(
                child: _buildContent(theme, context),
              ),

              // Footer
              _buildFooter(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // App title/logo
          Expanded(
            child: Row(
              children: [
                const Text(
                  '💜',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Menu',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Self Sync',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Close button
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            tooltip: 'Close menu',
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme, BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildMenuItem(
          icon: Icons.calendar_month_rounded,
          title: 'Calendar',
          onTap: () {
            if (onCalendarTap != null) {
              onCalendarTap!();
            }
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.edit_note_rounded,
          title: 'Diary',
          onTap: () {
            if (onDiaryTap != null) {
              onDiaryTap!();
            }
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.insights_rounded,
          title: 'Trends',
          onTap: () {
            if (onTrendsTap != null) {
              onTrendsTap!();
            }
            onClose();
          },
          theme: theme,
        ),

        const Divider(height: 32, indent: 16, endIndent: 16),

        _buildMenuItem(
          icon: Icons.settings_rounded,
          title: 'Settings',
          onTap: () {
            if (onSettingsTap != null) {
              onSettingsTap!();
            } else {
              onClose();
            }
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Help',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => HelpScreen(
                  drawerController: SideDrawerController(),
                ),
              ),
            );
            onClose();
          },
          theme: theme,
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        size: 24,
        color: theme.colorScheme.primary,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 16),
          Text(
            'Version 1.0.0 - Alpha',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '© 2025 Self Sync',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Controller for managing the side drawer state
class SideDrawerController extends ChangeNotifier {
  bool _isOpen = false;

  bool get isOpen => _isOpen;

  void open() {
    AppLogger.info('Opening drawer', tag: 'SideDrawerController');
    _isOpen = true;
    notifyListeners();
    AppLogger.success('Drawer opened, listeners notified', tag: 'SideDrawerController');
  }

  void close() {
    AppLogger.info('Closing drawer', tag: 'SideDrawerController');
    _isOpen = false;
    notifyListeners();
    AppLogger.success('Drawer closed, listeners notified', tag: 'SideDrawerController');
  }

  void toggle() {
    AppLogger.info('Toggling drawer', tag: 'SideDrawerController');
    _isOpen = !_isOpen;
    notifyListeners();
    AppLogger.success('Drawer toggled to ${_isOpen ? "OPEN" : "CLOSED"}', tag: 'SideDrawerController');
  }
}

/// Widget that adds drawer functionality to a screen
/// Wrap your screen's Scaffold with this widget
class DrawerWrapper extends StatefulWidget {
  final Widget child;
  final SideDrawerController? controller;
  final VoidCallback? onSettingsTap;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onDiaryTap;
  final VoidCallback? onTrendsTap;

  const DrawerWrapper({
    super.key,
    required this.child,
    this.controller,
    this.onSettingsTap,
    this.onCalendarTap,
    this.onDiaryTap,
    this.onTrendsTap,
  });

  @override
  State<DrawerWrapper> createState() => _DrawerWrapperState();
}

class _DrawerWrapperState extends State<DrawerWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late SideDrawerController _controller;

  @override
  void initState() {
    super.initState();

    AppLogger.lifecycle('DrawerWrapper initializing', tag: 'DrawerWrapper');

    _controller = widget.controller ?? SideDrawerController();
    _controller.addListener(_handleDrawerStateChange);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    AppLogger.success('DrawerWrapper initialized', tag: 'DrawerWrapper');
  }

  @override
  void dispose() {
    AppLogger.lifecycle('DrawerWrapper disposing', tag: 'DrawerWrapper');
    _controller.removeListener(_handleDrawerStateChange);
    _animationController.dispose();
    super.dispose();
  }

  void _handleDrawerStateChange() {
    AppLogger.info(
      'Drawer state changed: ${_controller.isOpen ? "OPEN" : "CLOSED"}',
      tag: 'DrawerWrapper',
    );

    if (_controller.isOpen) {
      AppLogger.debug('Animating drawer FORWARD (opening)', tag: 'DrawerWrapper');
      _animationController.forward();
    } else {
      AppLogger.debug('Animating drawer REVERSE (closing)', tag: 'DrawerWrapper');
      _animationController.reverse();
    }

    // ⚡ OPTIMIZATION: Removed setState() call!
    // AnimatedBuilder will automatically rebuild overlay when animation changes
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth < 400
        ? screenWidth * 0.7
        : screenWidth < 600
        ? screenWidth * 0.5
        : screenWidth * 0.25;

    AppLogger.debug(
      'Building DrawerWrapper - Drawer is ${_controller.isOpen ? "OPEN" : "CLOSED"}',
      tag: 'DrawerWrapper',
    );

    return Stack(
      children: [
        // Main content - wrapped in RepaintBoundary for better performance
        RepaintBoundary(
          child: widget.child,
        ),

        // ⚡ OPTIMIZATION: AnimatedBuilder only rebuilds overlay, not main content
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            // Only show overlay during animation or when open
            if (_animationController.value == 0) {
              return const SizedBox.shrink();
            }

            return Positioned.fill(
              child: Row(
                children: [
                  // Drawer area - overlay visible but taps go through to drawer
                  SizedBox(
                    width: drawerWidth,
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.5 * _animationController.value,
                        ),
                      ),
                    ),
                  ),

                  // Rest of screen - overlay that closes drawer on tap
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        AppLogger.warning('🎯 OVERLAY TAPPED - Closing drawer', tag: 'DrawerWrapper');
                        _controller.close();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        color: Colors.black.withValues(
                          alpha: 0.5 * _animationController.value,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),

        // Sliding drawer - On top of overlay
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SideDrawer(
              onClose: () {
                AppLogger.info('Close button pressed in drawer', tag: 'DrawerWrapper');
                _controller.close();
              },
              onSettingsTap: widget.onSettingsTap,
              onCalendarTap: widget.onCalendarTap,
              onDiaryTap: widget.onDiaryTap,
              onTrendsTap: widget.onTrendsTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Hamburger menu button that opens the drawer
class HamburgerMenuButton extends StatelessWidget {
  final SideDrawerController controller;

  const HamburgerMenuButton({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: controller.open,
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Open menu',
    );
  }
}