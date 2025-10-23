import 'package:flutter/material.dart';

/// A custom side drawer that slides in from the left side of the screen
/// Occupies 1/4 of screen width with smooth animation
class SideDrawer extends StatelessWidget {
  final VoidCallback onClose;

  const SideDrawer({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    // Use a minimum width to prevent overflow on narrow screens
    final drawerWidth = screenWidth < 400
        ? screenWidth * 0.7  // 70% on very small screens
        : screenWidth < 600
        ? screenWidth * 0.5  // 50% on small screens
        : screenWidth * 0.25; // 25% on larger screens

    return Material(
      color: Colors.transparent,
      child: Container(
        width: drawerWidth,
        constraints: BoxConstraints(
          minWidth: 200, // Minimum width to prevent overflow
          maxWidth: 400, // Maximum width for very large screens
        ),
        decoration: BoxDecoration(
          color: Colors.white,
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
                child: _buildContent(theme),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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

  Widget _buildContent(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _buildMenuItem(
          icon: Icons.home_rounded,
          title: 'Home',
          onTap: () {
            // TODO: Navigate to home
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.calendar_month_rounded,
          title: 'Calendar',
          onTap: () {
            // TODO: Navigate to calendar
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.edit_note_rounded,
          title: 'Diary',
          onTap: () {
            // TODO: Navigate to diary
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.insights_rounded,
          title: 'Trends',
          onTap: () {
            // TODO: Navigate to trends
            onClose();
          },
          theme: theme,
        ),

        const Divider(height: 32, indent: 16, endIndent: 16),

        _buildMenuItem(
          icon: Icons.settings_rounded,
          title: 'Settings',
          onTap: () {
            // TODO: Navigate to settings
            onClose();
          },
          theme: theme,
        ),
        _buildMenuItem(
          icon: Icons.help_outline_rounded,
          title: 'Help',
          onTap: () {
            // TODO: Show help
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
            'Version 1.0.0',
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
    _isOpen = true;
    notifyListeners();
  }

  void close() {
    _isOpen = false;
    notifyListeners();
  }

  void toggle() {
    _isOpen = !_isOpen;
    notifyListeners();
  }
}

/// Widget that adds drawer functionality to a screen
/// Wrap your screen's Scaffold with this widget
class DrawerWrapper extends StatefulWidget {
  final Widget child;
  final SideDrawerController? controller;

  const DrawerWrapper({
    super.key,
    required this.child,
    this.controller,
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
  }

  @override
  void dispose() {
    _controller.removeListener(_handleDrawerStateChange);
    _animationController.dispose();
    super.dispose();
  }

  void _handleDrawerStateChange() {
    if (_controller.isOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main content
        widget.child,

        // Overlay when drawer is open
        if (_controller.isOpen)
          GestureDetector(
            onTap: _controller.close,
            child: AnimatedOpacity(
              opacity: _controller.isOpen ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),

        // Sliding drawer
        SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerLeft,
            child: SideDrawer(
              onClose: _controller.close,
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