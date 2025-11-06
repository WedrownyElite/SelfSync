import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';

class HelpScreen extends StatefulWidget {
  final SideDrawerController drawerController;
  final GlobalKey? contentKey;

  const HelpScreen({
    super.key,
    required this.drawerController,
    this.contentKey,
  });

  @override
  State<HelpScreen> createState() => HelpScreenState();
}

class HelpScreenState extends State<HelpScreen> {
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedSections = {};

  // Onboarding control
  bool _isOnboardingActive = false;
  int _onboardingStep = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void startOnboarding() {
    setState(() {
      _isOnboardingActive = true;
      _onboardingStep = 0;
    });
    AppLogger.info('Help onboarding started', tag: 'HelpScreen');
  }

  void setOnboardingStep(int step) {
    setState(() {
      _onboardingStep = step;
    });
    AppLogger.info('Help onboarding step set to: $step', tag: 'HelpScreen');
  }

  void endOnboarding() {
    setState(() {
      _isOnboardingActive = false;
      _onboardingStep = 0;
    });
    AppLogger.info('Help onboarding ended', tag: 'HelpScreen');
  }

  void scrollToWidget(GlobalKey? key) {
    if (key == null) {
      AppLogger.warning('Cannot scroll - key is null', tag: 'HelpScreen');
      return;
    }

    final screenHeight = MediaQuery.of(context).size.height;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject == null || renderObject is! RenderBox) {
          AppLogger.warning('Cannot scroll - render object is null or not a RenderBox', tag: 'HelpScreen');
          return;
        }

        try {
          final widgetPosition = renderObject.localToGlobal(Offset.zero);
          final widgetHeight = renderObject.size.height;
          final currentScroll = _scrollController.offset;

          const headerHeight = 80.0;
          final viewportTop = headerHeight;
          final viewportBottom = screenHeight - 100;
          final viewportHeight = viewportBottom - viewportTop;

          final widgetTopInViewport = widgetPosition.dy;

          AppLogger.info('Widget position - Top: $widgetTopInViewport', tag: 'HelpScreen.Scroll');

          final targetScrollOffset = currentScroll + widgetTopInViewport - viewportTop - (viewportHeight / 2) + (widgetHeight / 2);

          final maxScroll = _scrollController.position.maxScrollExtent;
          final minScroll = _scrollController.position.minScrollExtent;
          final finalScroll = targetScrollOffset.clamp(minScroll, maxScroll);

          AppLogger.info('Scrolling from $currentScroll to $finalScroll (max: $maxScroll)', tag: 'HelpScreen.Scroll');

          _scrollController.animateTo(
            finalScroll,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );

          AppLogger.success('Scroll animation started', tag: 'HelpScreen.Scroll');
        } catch (e, stackTrace) {
          AppLogger.error('Failed to scroll to widget: $e\n$stackTrace', tag: 'HelpScreen.Scroll');
        }
      });
    });
  }

  void scrollToTop() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      if (!_scrollController.hasClients) {
        AppLogger.warning('ScrollController not attached yet', tag: 'HelpScreen.Scroll');
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: ListView(
                key: widget.contentKey,
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),

                  // Quick Actions Section
                  _buildQuickActionsCard(theme),
                  const SizedBox(height: 24),

                  // Getting Started Tutorial
                  _buildExpandableSection(
                    theme: theme,
                    id: 'getting_started',
                    icon: Icons.rocket_launch_rounded,
                    title: 'Getting Started',
                    subtitle: 'Learn the basics of Self Sync',
                    content: _buildGettingStartedContent(theme),
                  ),

                  // How to Track Mood
                  _buildExpandableSection(
                    theme: theme,
                    id: 'track_mood',
                    icon: Icons.edit_note_rounded,
                    title: 'How to Track Your Mood',
                    subtitle: 'Log your daily emotions',
                    content: _buildTrackMoodContent(theme),
                  ),

                  _buildExpandableSection(
                    theme: theme,
                    id: 'gestures',
                    icon: Icons.swipe_rounded,
                    title: 'Gestures & Shortcuts',
                    subtitle: 'Faster ways to interact',
                    content: _buildGesturesContent(theme),
                  ),

                  // How to Edit Mood
                  _buildExpandableSection(
                    theme: theme,
                    id: 'editing',
                    icon: Icons.edit_rounded,
                    title: 'Editing & Deleting Entries',
                    subtitle: 'Manage your mood entries',
                    content: _buildEditingContent(theme),
                  ),

                  // Understanding Mood Scale
                  _buildExpandableSection(
                    theme: theme,
                    id: 'mood_scale',
                    icon: Icons.sentiment_satisfied_alt_rounded,
                    title: 'Understanding the Mood Scale',
                    subtitle: '1-10 rating system explained',
                    content: _buildMoodScaleContent(theme),
                  ),

                  // Calendar Features
                  _buildExpandableSection(
                    theme: theme,
                    id: 'calendar',
                    icon: Icons.calendar_month_rounded,
                    title: 'Using the Calendar',
                    subtitle: 'View your mood history',
                    content: _buildCalendarContent(theme),
                  ),

                  // Trends & Analytics
                  _buildExpandableSection(
                    theme: theme,
                    id: 'trends',
                    icon: Icons.insights_rounded,
                    title: 'Trends & Analytics',
                    subtitle: 'Understand your patterns',
                    content: _buildTrendsContent(theme),
                  ),

                  // Theme Customization
                  _buildExpandableSection(
                    theme: theme,
                    id: 'themes',
                    icon: Icons.palette_rounded,
                    title: 'Customizing Themes',
                    subtitle: 'Personalize your experience',
                    content: _buildThemesContent(theme),
                  ),

                  // Data & Privacy
                  _buildExpandableSection(
                    theme: theme,
                    id: 'privacy',
                    icon: Icons.privacy_tip_rounded,
                    title: 'Data & Privacy',
                    subtitle: 'How we protect your information',
                    content: _buildPrivacyContent(theme),
                  ),

                  // Tips & Tricks
                  _buildExpandableSection(
                    theme: theme,
                    id: 'tips',
                    icon: Icons.lightbulb_outline_rounded,
                    title: 'Tips & Tricks',
                    subtitle: 'Get the most out of Self Sync',
                    content: _buildTipsContent(theme),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 8),
          Text(
            '💜',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'Help & Support',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditingContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem(
          theme: theme,
          step: '1',
          title: 'Long Press to Edit/Delete',
          description: 'Long press any mood entry to see edit and delete options.',
        ),
        _buildStepItem(
          theme: theme,
          step: '2',
          title: 'Swipe to Delete',
          description: 'Swipe a mood entry to the right to quickly delete it.',
        ),
        _buildStepItem(
          theme: theme,
          step: '3',
          title: 'Edit Your Entry',
          description: 'Tap edit to modify the message and mood rating. The entry keeps its original timestamp.',
        ),
        _buildInfoBox(
          theme: theme,
          icon: Icons.info_outline_rounded,
          text: 'Deleted entries cannot be recovered. Make sure you want to delete before confirming!',
        ),
      ],
    );
  }

  Widget _buildGesturesContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem(
          theme: theme,
          step: '1',
          title: 'Long Press',
          description: 'Long press any mood entry to see edit and delete options in a quick menu.',
        ),
        _buildStepItem(
          theme: theme,
          step: '2',
          title: 'Swipe to Delete',
          description: 'Swipe a mood entry to the right to reveal the delete action. Swipe far enough to trigger deletion.',
        ),
        _buildStepItem(
          theme: theme,
          step: '3',
          title: 'Calendar Date Tap',
          description: 'Tap any date in the calendar to filter your diary to that day. Tap a second date to create a date range.',
        ),
        _buildStepItem(
          theme: theme,
          step: '4',
          title: 'Scroll to Bottom',
          description: 'When viewing older entries, tap the down arrow button to quickly jump to your most recent entries.',
        ),
        const SizedBox(height: 16),
        _buildInfoBox(
          theme: theme,
          icon: Icons.tips_and_updates_rounded,
          text: 'Tip: These gestures make managing your mood diary faster and more intuitive!',
        ),
      ],
    );
  }

  Widget _buildQuickActionsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.secondary,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Need Help?',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Get in touch with our support team',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildQuickActionButton(
                icon: Icons.email_rounded,
                label: 'Email Support',
                onTap: () => _launchEmail('support@oddologyinc.com'),
              ),
              _buildQuickActionButton(
                icon: Icons.bug_report_rounded,
                label: 'Report Bug',
                onTap: () => _launchEmail('support@oddologyinc.com', subject: 'Bug Report'),
              ),
              _buildQuickActionButton(
                icon: Icons.web_rounded,
                label: 'Website',
                onTap: () => _launchURL('https://moodflow.oddologyinc.com'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExpandableSection({
    required ThemeData theme,
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget content,
  }) {
    final isExpanded = _expandedSections.contains(id);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedSections.remove(id);
                } else {
                  _expandedSections.add(id);
                }
              });
              AppLogger.info('Help section ${isExpanded ? "collapsed" : "expanded"}: $title', tag: 'Help');
            },
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.2),
                          theme.colorScheme.secondary.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: theme.colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
        ],
      ),
    );
  }

  Widget _buildGettingStartedContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepItem(
          theme: theme,
          step: '1',
          title: 'Track Your Mood',
          description: 'Tap the Diary tab to log how you\'re feeling. Rate your mood from 1-10 and add optional notes.',
        ),
        _buildStepItem(
          theme: theme,
          step: '2',
          title: 'View Your History',
          description: 'Use the Calendar tab to see your mood patterns over time with color-coded days.',
        ),
        _buildStepItem(
          theme: theme,
          step: '3',
          title: 'Analyze Trends',
          description: 'Check the Trends tab for insights into your emotional patterns and progress.',
        ),
        _buildStepItem(
          theme: theme,
          step: '4',
          title: 'Customize Your Experience',
          description: 'Visit Settings to choose your preferred theme and personalize the app.',
        ),
      ],
    );
  }

  Widget _buildTrackMoodContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoBox(
          theme: theme,
          icon: Icons.edit_note_rounded,
          text: 'Go to the Diary tab to start tracking your mood.',
        ),
        const SizedBox(height: 16),
        _buildBulletPoint(theme, 'Select a mood rating from 1 (lowest) to 10 (highest)'),
        _buildBulletPoint(theme, 'Add notes to remember what influenced your mood'),
        _buildBulletPoint(theme, 'Track multiple entries throughout the day'),
        _buildBulletPoint(theme, 'Your data is saved locally and privately on your device'),
      ],
    );
  }

  Widget _buildMoodScaleContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMoodRangeCard(theme, '1-3', 'Low Mood', 'Feeling down, stressed, or struggling', Colors.red),
        const SizedBox(height: 12),
        _buildMoodRangeCard(theme, '4-7', 'Neutral/Good', 'Stable, content, or moderately happy', Colors.orange),
        const SizedBox(height: 12),
        _buildMoodRangeCard(theme, '8-10', 'Great Mood', 'Feeling excellent, joyful, or energized', Colors.green),
        const SizedBox(height: 16),
        _buildInfoBox(
          theme: theme,
          icon: Icons.tips_and_updates_rounded,
          text: 'Tip: Be honest with your ratings to get meaningful insights over time.',
        ),
      ],
    );
  }

  Widget _buildCalendarContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(theme, 'Each day is color-coded based on your average mood'),
        _buildBulletPoint(theme, 'Tap any date to view all entries from that day'),
        _buildBulletPoint(theme, 'Use the month/year picker to navigate to different time periods'),
        _buildBulletPoint(theme, 'Select date ranges to view entries from multiple days'),
        const SizedBox(height: 16),
        _buildInfoBox(
          theme: theme,
          icon: Icons.palette_rounded,
          text: 'Color intensity reflects your mood: darker = lower, brighter = higher.',
        ),
      ],
    );
  }

  Widget _buildTrendsContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(theme, 'View mood trends over different time periods (7D, 30D, 90D, All)'),
        _buildBulletPoint(theme, 'See your average mood and highest/lowest points'),
        _buildBulletPoint(theme, 'Identify patterns in your emotional well-being'),
        _buildBulletPoint(theme, 'Track your progress over time'),
        const SizedBox(height: 16),
        _buildInfoBox(
          theme: theme,
          icon: Icons.info_outline_rounded,
          text: 'Regular tracking provides more accurate trend analysis.',
        ),
      ],
    );
  }

  Widget _buildThemesContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(theme, 'Choose between Light, Dark, or System theme modes'),
        _buildBulletPoint(theme, 'Select from various color gradients to personalize your app'),
        _buildBulletPoint(theme, 'Theme changes apply instantly across all screens'),
        _buildBulletPoint(theme, 'Your preferences are saved automatically'),
        const SizedBox(height: 16),
        _buildInfoBox(
          theme: theme,
          icon: Icons.settings_rounded,
          text: 'Access theme settings by tapping the menu → Settings.',
        ),
      ],
    );
  }

  Widget _buildPrivacyContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBulletPoint(theme, 'All mood data is stored locally on your device'),
        _buildBulletPoint(theme, 'No personal information is shared without your consent'),
        _buildBulletPoint(theme, 'Your mood entries remain completely private'),
        _buildBulletPoint(theme, 'Data is encrypted and secure'),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: () => _launchURL('https://moodflow.oddologyinc.com/#privacy'),
          icon: Icon(Icons.open_in_new_rounded, size: 18, color: theme.colorScheme.primary),
          label: Text(
            'Read Full Privacy Policy',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: () => _launchURL('https://moodflow.oddologyinc.com/#terms'),
          icon: Icon(Icons.open_in_new_rounded, size: 18, color: theme.colorScheme.primary),
          label: Text(
            'Read Terms of Service',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTipCard(
          theme: theme,
          icon: Icons.schedule_rounded,
          title: 'Track Consistently',
          description: 'Log your mood at the same times each day for better pattern recognition.',
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          theme: theme,
          icon: Icons.touch_app_rounded,
          title: 'Quick Actions',
          description: 'Long press entries for quick edit/delete, or swipe right to delete.',
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          theme: theme,
          icon: Icons.notes_rounded,
          title: 'Add Context',
          description: 'Include notes about what affected your mood to identify triggers.',
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          theme: theme,
          icon: Icons.trending_up_rounded,
          title: 'Review Trends',
          description: 'Check your trends weekly to understand your emotional patterns.',
        ),
        const SizedBox(height: 12),
        _buildTipCard(
          theme: theme,
          icon: Icons.favorite_rounded,
          title: 'Be Patient',
          description: 'Meaningful insights come from consistent tracking over time.',
        ),
      ],
    );
  }

  Widget _buildStepItem({
    required ThemeData theme,
    required String step,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodRangeCard(ThemeData theme, String range, String label, String description, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              range,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color.withValues(alpha: 0.9),
                  ),
                ),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox({
    required ThemeData theme,
    required IconData icon,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: theme.colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(ThemeData theme, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email, {String? subject}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: subject != null ? 'subject=$subject' : null,
    );

    AppLogger.info('Attempting to launch email: $email', tag: 'Help');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
        AppLogger.success('Email client opened successfully', tag: 'Help');
      } else {
        AppLogger.error('Could not launch email client', tag: 'Help');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Please email us at: $email'),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error launching email', tag: 'Help', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please email us at: $email'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);

    AppLogger.info('Attempting to launch URL: $url', tag: 'Help');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        AppLogger.success('URL opened successfully', tag: 'Help');
      } else {
        AppLogger.error('Could not launch URL', tag: 'Help');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open: $url'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.error('Error launching URL', tag: 'Help', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open: $url'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
}