import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/mood_entry.dart';
import '../services/mood_service.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';
import '../services/theme_service.dart';
import '../utils/performance_test_helper.dart';
import '../widgets/interactive_tutorial_overlay.dart';

class TrendsScreen extends StatefulWidget {
  final MoodService moodService;
  final Function(int tabIndex, DateTime? date)? onNavigateToTab;
  final SideDrawerController drawerController;
  final ThemeService themeService;
  final GlobalKey? datePresetsKey;
  final GlobalKey? comparisonKey;
  final GlobalKey? streakKey;
  final GlobalKey? averageMoodKey;
  final GlobalKey? bestDayKey;
  final GlobalKey? toughestDayKey;
  final GlobalKey? moodChartKey;
  final GlobalKey? activityKey;
  final GlobalKey? distributionKey;
  final GlobalKey? insightsKey;
  final GlobalKey? peakTimeKey;
  final GlobalKey? consistencyKey;

  const TrendsScreen({
    super.key,
    required this.moodService,
    this.onNavigateToTab,
    required this.drawerController,
    required this.themeService,
    this.datePresetsKey,
    this.streakKey,
    this.averageMoodKey,
    this.bestDayKey,
    this.toughestDayKey,
    this.moodChartKey,
    this.activityKey,
    this.distributionKey,
    this.insightsKey,
    this.comparisonKey,
    this.peakTimeKey,
    this.consistencyKey,
  });

  @override
  State<TrendsScreen> createState() => TrendsScreenState();
}

class TrendsScreenState extends State<TrendsScreen> with TickerProviderStateMixin {
  String _selectedRange = '7D';
  final PageController _distributionPageController = PageController();
  int _currentDistributionPage = 0;

  final ScrollController _scrollController = ScrollController();
  
  // Month/Year picker state
  bool _isMonthPickerVisible = false;
  bool _isYearPickerVisible = false;
  late AnimationController _monthPickerController;
  late AnimationController _yearPickerController;

  // Date formatters
  static final _monthFormat = DateFormat('MMMM');
  static final _dateFormat = DateFormat('MMM d, yyyy');

  // Onboarding control
  // ignore: unused_field
  bool _isOnboardingActive = false;
  // ignore: unused_field
  int _onboardingStep = 0;

  // Custom date range state
  bool _isCalendarExpanded = false;
  DateTime _selectedCalendarMonth = DateTime.now();
  DateTime? _customStartDate;
  DateTime? _customEndDate;
  late AnimationController _calendarExpandController;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _calendarExpandController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _monthPickerController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _yearPickerController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    // Listen to mood service changes
    widget.moodService.addListener(_onMoodServiceUpdate);
    AppLogger.lifecycle('Started listening to MoodService updates', tag: 'TrendsScreen');
  }

  @override
  void dispose() {
    _calendarExpandController.dispose();
    _monthPickerController.dispose();
    _yearPickerController.dispose();
    _scrollController.dispose();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    _distributionPageController.dispose();
    AppLogger.lifecycle('Stopped listening to MoodService updates', tag: 'TrendsScreen');
    super.dispose();
  }

  void startOnboarding() {
    setState(() {
      _isOnboardingActive = true;
      _onboardingStep = 0;
    });
    AppLogger.info('Trends onboarding started', tag: 'TrendsScreen');
  }

  void setOnboardingStep(int step) {
    setState(() {
      _onboardingStep = step;
    });
    AppLogger.info('Trends onboarding step set to: $step', tag: 'TrendsScreen');
  }

  void endOnboarding() {
    setState(() {
      _isOnboardingActive = false;
      _onboardingStep = 0;
    });
    AppLogger.info('Trends onboarding ended', tag: 'TrendsScreen');
  }

  void scrollToWidget(GlobalKey? key) {
    if (key == null) {
      AppLogger.warning('Cannot scroll - key is null', tag: 'TrendsScreen');
      return;
    }

    // Capture screen height before async operations
    final screenHeight = MediaQuery.of(context).size.height;

    // Wait for the widget to be rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;

        // Get RenderObject directly from the key instead of using context
        final renderObject = key.currentContext?.findRenderObject();
        if (renderObject == null || renderObject is! RenderBox) {
          AppLogger.warning('Cannot scroll - render object is null or not a RenderBox', tag: 'TrendsScreen');
          return;
        }

        try {
          // Get the RenderBox of the target widget
          final widgetPosition = renderObject.localToGlobal(Offset.zero);
          final widgetHeight = renderObject.size.height;

          // Get the current scroll position
          final currentScroll = _scrollController.offset;

          // Calculate where the widget currently is relative to the viewport
          const headerHeight = 150.0;
          final viewportTop = headerHeight;
          final viewportBottom = screenHeight - 100;
          final viewportHeight = viewportBottom - viewportTop;

          // Widget position relative to the current scroll
          final widgetTopInViewport = widgetPosition.dy;

          AppLogger.info('Widget position - Top: $widgetTopInViewport', tag: 'TrendsScreen.Scroll');

          // ALWAYS scroll to center the widget - remove the visibility check
          // Calculate target scroll position to center the widget in the viewport
          final targetScrollOffset = currentScroll + widgetTopInViewport - viewportTop - (viewportHeight / 2) + (widgetHeight / 2);

          // Clamp to valid scroll range
          final maxScroll = _scrollController.position.maxScrollExtent;
          final minScroll = _scrollController.position.minScrollExtent;
          final finalScroll = targetScrollOffset.clamp(minScroll, maxScroll);

          AppLogger.info('Scrolling from $currentScroll to $finalScroll (max: $maxScroll)', tag: 'TrendsScreen.Scroll');

          // Scroll to center the widget
          _scrollController.animateTo(
            finalScroll,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
          );

          AppLogger.success('Scroll animation started', tag: 'TrendsScreen.Scroll');
        } catch (e, stackTrace) {
          AppLogger.error('Failed to scroll to widget: $e\n$stackTrace', tag: 'TrendsScreen.Scroll');
        }
      });
    });
  }

  void scrollToTop() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) return;

      // Check if scroll controller is attached
      if (!_scrollController.hasClients) {
        AppLogger.warning('ScrollController not attached yet', tag: 'TrendsScreen.Scroll');
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onMoodServiceUpdate() {
    if (mounted) {
      AppLogger.debug('MoodService update received, rebuilding UI', tag: 'TrendsScreen');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    PerformanceTestHelper.recordBuild('TrendsScreen');

    final theme = Theme.of(context);

    // Debug logging
    AppLogger.separator(label: 'TRENDS SCREEN DEBUG');
    AppLogger.data('Total entries in service',
        details: '${widget.moodService.entries.length}',
        tag: 'TrendsScreen'
    );
    AppLogger.info('Selected range: $_selectedRange', tag: 'TrendsScreen');

    if (widget.moodService.entries.isNotEmpty) {
      AppLogger.info('Sample entries (first ${widget.moodService.entries.length.clamp(0, 5)}):',
          tag: 'TrendsScreen'
      );

      for (var i = 0; i < widget.moodService.entries.length.clamp(0, 5); i++) {
        final entry = widget.moodService.entries[i];
        AppLogger.debug('Entry $i: ${entry.timestamp} - Mood: ${entry.moodRating}',
            tag: 'TrendsScreen'
        );
      }

      final oldest = widget.moodService.entries.last;
      final newest = widget.moodService.entries.first;

      AppLogger.prettyPrint({
        'Oldest entry': oldest.timestamp.toString(),
        'Newest entry': newest.timestamp.toString(),
        'Date span': '${newest.timestamp.difference(oldest.timestamp).inDays} days',
      }, title: 'Date Range', tag: 'TrendsScreen');
    }

    final entries = _getEntriesForRange(widget.moodService.entries, _selectedRange);

    AppLogger.success('Filtered entries: ${entries.length}', tag: 'TrendsScreen');

    if (entries.isNotEmpty && entries.length <= 5) {
      AppLogger.list(
          'Filtered entry dates',
          entries.map((e) => e.timestamp.toString()).toList(),
          tag: 'TrendsScreen'
      );
    }
    AppLogger.separator();

    // Always check the TOTAL entries, not just filtered
    final hasAnyData = widget.moodService.entries.isNotEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            if (hasAnyData) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildTimeRangeSelector(theme),
              ),
            ],
            Expanded(
              child: !hasAnyData
                  ? _buildEmptyState(theme)
                  : entries.isEmpty
                  ? _buildNoDataForRangeState(theme)
                  : ListView(
                controller: _scrollController,
                physics: _isOnboardingActive
                    ? const NeverScrollableScrollPhysics()
                    : null,
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  _buildInsights(theme, entries),
                  const SizedBox(height: 24),
                  _buildComparisonCard(theme, _getComparisonData(widget.moodService.entries, _selectedRange)),
                  const SizedBox(height: 24),
                  _buildStatsGrid(theme, entries),
                  const SizedBox(height: 24),
                  _buildMoodChart(theme, entries),
                  const SizedBox(height: 24),
                  _buildMoodDistribution(theme, entries),
                  const SizedBox(height: 24),
                  _buildActivityCalendar(theme, entries),
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
          // Hamburger menu button
          IconButton(
            // REMOVED: key: widget.hamburgerKey,
            onPressed: () => widget.drawerController.open(),
            icon: const Icon(Icons.menu_rounded),
            tooltip: 'Open menu',
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Trends',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Understand your patterns',
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 48,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No mood data yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start logging your moods to see\nyour trends and insights here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoDataForRangeState(ThemeData theme) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 48,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No data for this time range',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Try selecting a different time range\nor log more moods',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(ThemeData theme) {
    final ranges = ['7D', '30D', '3M', 'YTD', 'Year', 'Lifetime', 'Custom'];

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            key: widget.datePresetsKey,
            children: ranges.asMap().entries.map((entry) {
              final index = entry.key;
              final range = entry.value;
              final isSelected = _selectedRange == range;
              final isLast = index == ranges.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppLogger.info(
                              'Time range changed: $_selectedRange → $range',
                              tag: 'TrendsScreen.Selector'
                          );

                          if (range == 'Custom') {
                            setState(() {
                              _isCalendarExpanded = !_isCalendarExpanded;
                              _selectedRange = range;
                              if (_isCalendarExpanded) {
                                _calendarExpandController.forward();
                              } else {
                                _calendarExpandController.reverse();
                              }
                            });
                          } else {
                            setState(() {
                              _selectedRange = range;
                              _isCalendarExpanded = false;
                              _customStartDate = null;
                              _customEndDate = null;
                              _calendarExpandController.reverse();
                            });

                            // Progress onboarding when date range is tapped during step 11
                            if (_isOnboardingActive && _onboardingStep == 11) {
                              AppLogger.info('Date range selected during onboarding - progressing', tag: 'Onboarding');
                              OnboardingController.nextStep();
                            }
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? theme.colorScheme.surface : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: isSelected
                                ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ]
                                : null,
                          ),
                          child: Text(
                            range,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      // Seperate buttons with vertical lines
                      if (!isLast)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 1,
                          height: 16,
                          color: (isSelected || _selectedRange == ranges[index + 1])
                              ? Colors.transparent
                              : theme.colorScheme.onSurface.withValues(alpha: 0.12),
                        ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        // Expandable calendar
        if (_selectedRange == 'Custom')
          _buildExpandableCalendar(theme),
      ],
    );
  }

  Widget _buildExpandableCalendar(ThemeData theme) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(
        parent: _calendarExpandController,
        curve: Curves.easeInOutCubic,
      ),
      child: Container(
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(16),
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
        child: Stack(
          children: [
            Column(
              children: [
                _buildMonthYearSelector(theme),
                const SizedBox(height: 16),
                _buildCalendarGrid(theme),
                if (_customStartDate != null || _customEndDate != null) ...[
                  const SizedBox(height: 16),
                  _buildSelectedDateDisplay(theme),
                ],
              ],
            ),

            // Month picker overlay
            if (_isMonthPickerVisible)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: _buildMonthPicker(theme),
              ),

            // Year picker overlay
            if (_isYearPickerVisible)
              Positioned(
                top: 50,
                left: 0,
                right: 0,
                child: _buildYearPicker(theme),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthYearSelector(ThemeData theme) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    // Get earliest month with data
    final earliestDate = widget.moodService.entries.isEmpty
        ? now
        : widget.moodService.entries.last.timestamp;
    final earliestMonth = DateTime(earliestDate.year, earliestDate.month);

    // Check if we can navigate
    final canGoBack = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month - 1)
        .isAfter(DateTime(earliestMonth.year, earliestMonth.month - 1)) ||
        DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month - 1)
            .isAtSameMomentAs(earliestMonth);

    final canGoForward = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1)
        .isBefore(DateTime(currentMonth.year, currentMonth.month + 1)) ||
        DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1)
            .isAtSameMomentAs(currentMonth);

    return Column(
      children: [
        Row(
          children: [
            // Left arrow
            IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: canGoBack
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              onPressed: canGoBack ? () {
                setState(() {
                  _selectedCalendarMonth = DateTime(
                    _selectedCalendarMonth.year,
                    _selectedCalendarMonth.month - 1,
                  );
                });
              } : null,
            ),

            // Month button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isMonthPickerVisible = !_isMonthPickerVisible;
                    if (_isMonthPickerVisible) {
                      _isYearPickerVisible = false;
                      _monthPickerController.forward();
                      _yearPickerController.reverse();
                    } else {
                      _monthPickerController.reverse();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isMonthPickerVisible
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isMonthPickerVisible
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    _monthFormat.format(_selectedCalendarMonth),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isMonthPickerVisible
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Year button
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _isYearPickerVisible = !_isYearPickerVisible;
                    if (_isYearPickerVisible) {
                      _isMonthPickerVisible = false;
                      _yearPickerController.forward();
                      _monthPickerController.reverse();
                    } else {
                      _yearPickerController.reverse();
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isYearPickerVisible
                        ? theme.colorScheme.primary.withValues(alpha: 0.15)
                        : theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isYearPickerVisible
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '${_selectedCalendarMonth.year}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: _isYearPickerVisible
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),

            // Right arrow
            IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: canGoForward
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              onPressed: canGoForward ? () {
                setState(() {
                  _selectedCalendarMonth = DateTime(
                    _selectedCalendarMonth.year,
                    _selectedCalendarMonth.month + 1,
                  );
                });
              } : null,
            ),
          ],
        ),

        // Clear button on separate row
        if (_customStartDate != null || _customEndDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _customStartDate = null;
                    _customEndDate = null;
                  });
                },
                icon: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color: theme.colorScheme.error,
                ),
                label: Text(
                  'Clear Selection',
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMonthPicker(ThemeData theme) {
    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    // Get earliest month with data
    final earliestDate = widget.moodService.entries.isEmpty
        ? now
        : widget.moodService.entries.last.timestamp;
    final earliestMonth = DateTime(earliestDate.year, earliestDate.month);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ListWheelScrollView(
          controller: FixedExtentScrollController(
            initialItem: _selectedCalendarMonth.month - 1,
          ),
          itemExtent: 50,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            final selectedMonth = DateTime(_selectedCalendarMonth.year, index + 1);

            // Check if this month is valid (has data and not in future)
            final isInFuture = selectedMonth.isAfter(currentMonth);
            final isBeforeData = selectedMonth.isBefore(earliestMonth);

            if (!isInFuture && !isBeforeData) {
              HapticFeedback.selectionClick();
              setState(() {
                _selectedCalendarMonth = selectedMonth;
              });
            }
          },
          children: List.generate(12, (index) {
            final month = DateTime(_selectedCalendarMonth.year, index + 1);
            final isSelected = index == _selectedCalendarMonth.month - 1;

            // Check if this month is valid
            final isInFuture = month.isAfter(currentMonth);
            final isBeforeData = month.isBefore(earliestMonth);
            final isDisabled = isInFuture || isBeforeData;

            return Center(
              child: Text(
                _monthFormat.format(month),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isDisabled
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.25)
                      : isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isSelected ? 18 : 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildYearPicker(ThemeData theme) {
    final currentYear = DateTime.now().year;
    final currentMonth = DateTime.now().month;

    // Get earliest year with data
    final earliestDate = widget.moodService.entries.isEmpty
        ? DateTime.now()
        : widget.moodService.entries.last.timestamp;
    final earliestYear = earliestDate.year;

    final years = List.generate(
      currentYear - earliestYear + 1,
          (i) => earliestYear + i,
    );

    final initialIndex = years.indexOf(_selectedCalendarMonth.year);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: ListWheelScrollView(
          controller: FixedExtentScrollController(
            initialItem: initialIndex >= 0 ? initialIndex : years.length - 1,
          ),
          itemExtent: 50,
          diameterRatio: 1.5,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (index) {
            final selectedYear = years[index];

            // When changing year, clamp the month to valid range
            int newMonth = _selectedCalendarMonth.month;

            // If selecting current year, can't go past current month
            if (selectedYear == currentYear && newMonth > currentMonth) {
              newMonth = currentMonth;
            }

            // If selecting earliest year, can't go before earliest month
            if (selectedYear == earliestYear && newMonth < earliestDate.month) {
              newMonth = earliestDate.month;
            }

            HapticFeedback.selectionClick();
            setState(() {
              _selectedCalendarMonth = DateTime(selectedYear, newMonth);
            });
          },
          children: List.generate(years.length, (index) {
            final year = years[index];
            final isSelected = year == _selectedCalendarMonth.year;

            return Center(
              child: Text(
                '$year',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: isSelected ? 18 : 16,
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(ThemeData theme) {
    final firstDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, 1);
    final lastDayOfMonth = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final now = DateTime.now();

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),

        // Calendar days
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: 42, // 6 weeks max
          itemBuilder: (context, index) {
            if (index < startingWeekday || index >= startingWeekday + daysInMonth) {
              return const SizedBox();
            }

            final day = index - startingWeekday + 1;
            final date = DateTime(_selectedCalendarMonth.year, _selectedCalendarMonth.month, day);
            final isFuture = date.isAfter(now);
            final isSelected = (_customStartDate != null && _isSameDay(date, _customStartDate!)) ||
                (_customEndDate != null && _isSameDay(date, _customEndDate!));
            final isInRange = _customStartDate != null &&
                _customEndDate != null &&
                date.isAfter(_customStartDate!) &&
                date.isBefore(_customEndDate!);

            return GestureDetector(
              onTap: isFuture ? null : () {
                setState(() {
                  if (_customStartDate == null || (_customStartDate != null && _customEndDate != null)) {
                    // Start new selection
                    _customStartDate = date;
                    _customEndDate = null;
                  } else if (_customEndDate == null) {
                    // Complete selection
                    if (date.isBefore(_customStartDate!)) {
                      _customEndDate = _customStartDate;
                      _customStartDate = date;
                    } else {
                      _customEndDate = date;
                    }
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? theme.colorScheme.primary
                      : isInRange
                      ? theme.colorScheme.primary.withValues(alpha: 0.2)
                      : null,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 14,
                      color: isFuture
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                          : isSelected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildSelectedDateDisplay(ThemeData theme) {
    String text;
    if (_customStartDate != null && _customEndDate != null) {
      text = '${_dateFormat.format(_customStartDate!)} - ${_dateFormat.format(_customEndDate!)}';
    } else if (_customStartDate != null) {
      text = 'Start: ${_dateFormat.format(_customStartDate!)} (tap to select end date)';
    } else {
      text = 'Select dates';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.date_range_rounded,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final avgMood = entries.fold<int>(0, (sum, e) => sum + e.moodRating) /
        entries.length;

    // Calculate streaks from ALL entries (not filtered)
    final currentStreak = widget.moodService.getCurrentStreak();
    final bestStreak = widget.moodService.getBestStreak();

    // Find best and toughest days (from filtered entries)
    final bestEntry = entries.reduce((a, b) => a.moodRating > b.moodRating ? a : b);
    final toughestEntry = entries.reduce((a, b) => a.moodRating < b.moodRating ? a : b);

    // Calculate consistency score (based on variance)
    final consistencyData = _calculateConsistency(entries);

    return Column(
      children: [
        // First row: Streak and Average Mood
        Row(
          children: [
            Expanded(
              child: _buildStreakCard(
                theme,
                currentStreak,
                bestStreak,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                key: widget.averageMoodKey,
                child: _buildStatCard(
                  theme,
                  'Average Mood',
                  avgMood.toStringAsFixed(1),
                  Icons.sentiment_satisfied_alt_rounded,
                  null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Second row: Peak Time and Consistency
        Row(
          children: [
            Expanded(
              child: Container(
                key: widget.peakTimeKey,
                child: _buildStatCard(
                  theme,
                  'Peak Time',
                  _calculatePeakHour(entries) ?? 'N/A',
                  Icons.schedule_rounded,
                  null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                key: widget.consistencyKey,
                child: _buildConsistencyCard(
                  theme,
                  (consistencyData['score']! as num).toDouble(),
                  consistencyData['label']! as String,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

// Third row: Best and Worst Days
        Row(
          children: [
            Expanded(
              child: Container(
                key: widget.bestDayKey,
                child: _buildStatCard(
                  theme,
                  'Best Day',
                  _formatBestDayWithDate(bestEntry),
                  Icons.emoji_emotions_rounded,
                      () => _navigateToDiary(bestEntry.timestamp),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                key: widget.toughestDayKey,
                child: _buildStatCard(
                  theme,
                  'Toughest Day',
                  _formatToughestDayWithDate(toughestEntry),
                  Icons.mood_bad_rounded,
                      () => _navigateToDiary(toughestEntry.timestamp),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatBestDayWithDate(MoodEntry entry) {
    final date = DateFormat('MMM d').format(entry.timestamp);
    return '${MoodEntry.getMoodEmoji(entry.moodRating)} $date';
  }

  String _formatToughestDayWithDate(MoodEntry entry) {
    final date = DateFormat('MMM d').format(entry.timestamp);
    return '${MoodEntry.getMoodEmoji(entry.moodRating)} $date';
  }

  Map<String, dynamic> _calculateConsistency(List<MoodEntry> entries) {
    if (entries.length < 2) {
      return {'score': 100.0, 'label': 'Perfect'};
    }

    // Calculate variance
    final mean = entries.fold<int>(0, (sum, e) => sum + e.moodRating) / entries.length;
    final variance = entries.fold<double>(
      0.0,
          (sum, e) => sum + ((e.moodRating - mean) * (e.moodRating - mean)),
    ) / entries.length;

    // Calculate standard deviation
    final stdDev = sqrt(variance);

    // Convert to a 0-100 score (lower variance = higher score)
    // Max reasonable std dev for mood scale 1-10 is ~3 (very inconsistent)
    // We'll map 0 std dev = 100 score, 3 std dev = 0 score
    final consistencyScore = (100 - (stdDev / 3.0 * 100)).clamp(0, 100);

    // Determine label
    String label;
    if (consistencyScore >= 80) {
      label = 'Very Stable';
    } else if (consistencyScore >= 60) {
      label = 'Stable';
    } else if (consistencyScore >= 40) {
      label = 'Variable';
    } else if (consistencyScore >= 20) {
      label = 'Inconsistent';
    } else {
      label = 'Volatile';
    }

    return {
      'score': consistencyScore,
      'label': label,
    };
  }

  void _navigateToDiary(DateTime date) {
    AppLogger.navigation(
      'Trends Screen',
      'Mood Diary (${date.toString().split(' ')[0]})',
    );
    widget.onNavigateToTab?.call(1, date);
  }

  Widget _buildStatCard(
      ThemeData theme, String label, String value, IconData icon, VoidCallback? onTap) {
    final isInteractive = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isInteractive ? Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isInteractive)
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: theme.colorScheme.primary.withValues(alpha: 0.5),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConsistencyCard(ThemeData theme, double score, String label) {
    // Determine color and icon based on score
    Color indicatorColor;
    IconData icon;

    if (score >= 80) {
      indicatorColor = const Color(0xFF4CAF50); // Green - Very Stable
      icon = Icons.trending_flat_rounded;
    } else if (score >= 60) {
      indicatorColor = const Color(0xFF8BC34A); // Light Green - Stable
      icon = Icons.show_chart_rounded;
    } else if (score >= 40) {
      indicatorColor = const Color(0xFFFFC107); // Amber - Variable
      icon = Icons.waves_rounded;
    } else if (score >= 20) {
      indicatorColor = const Color(0xFFFF9800); // Orange - Inconsistent
      icon = Icons.swap_vert_rounded;
    } else {
      indicatorColor = const Color(0xFFFF5722); // Red - Volatile
      icon = Icons.multiple_stop_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: indicatorColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: indicatorColor,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Progress bar
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: score / 100,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Consistency',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${score.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 12,
                        color: indicatorColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakCard(ThemeData theme, int currentStreak, int bestStreak) {
    return Material(
      key: widget.streakKey,
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showStreakDialog(theme, currentStreak, bestStreak),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '🔥',
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '$currentStreak ${currentStreak == 1 ? 'day' : 'days'}',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Streak',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (bestStreak > currentStreak)
                    Text(
                      'Best: $bestStreak ${bestStreak == 1 ? 'day' : 'days'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStreakDialog(ThemeData theme, int currentStreak, int bestStreak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Text('🔥', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Text(
              'Streak Info',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Streak',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$currentStreak consecutive ${currentStreak == 1 ? 'day' : 'days'} with mood entries',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Best Streak',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$bestStreak ${bestStreak == 1 ? 'day' : 'days'} - your longest streak ever!',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                currentStreak >= bestStreak
                    ? '🎉 Amazing! You\'re on your best streak ever!'
                    : '💪 Keep going to beat your record of $bestStreak days!',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it!',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodChart(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Calculate daily averages first
    final Map<DateTime, double> dayAverages = {};
    final Map<DateTime, int> dayCounts = {};

    for (var entry in entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );

      dayAverages[date] = (dayAverages[date] ?? 0) + entry.moodRating;
      dayCounts[date] = (dayCounts[date] ?? 0) + 1;
    }

    dayAverages.forEach((date, sum) {
      dayAverages[date] = sum / dayCounts[date]!;
    });

    // Get sorted dates
    final sortedDates = dayAverages.keys.toList()..sort();
    final dataPointCount = sortedDates.length;

    // Smart aggregation based on data point count
    String aggregationType = 'Daily';
    final Map<DateTime, double> displayValues;

    if (dataPointCount > 180) {
      // More than 6 months of daily data - aggregate by month
      aggregationType = 'Monthly';
      displayValues = _aggregateByMonth(sortedDates, dayAverages);
    } else if (dataPointCount > 60) {
      // More than 2 months of daily data - aggregate by week
      aggregationType = 'Weekly';
      displayValues = _aggregateByWeek(sortedDates, dayAverages);
    } else {
      // 60 days or less - show daily
      aggregationType = 'Daily';
      displayValues = dayAverages;
    }

    final sortedDisplayDates = displayValues.keys.toList()..sort();
    final displayPointCount = sortedDisplayDates.length;
    final maxMood = 10.0;

    // Determine if we need scrolling (more than 50 points to display)
    final needsScrolling = displayPointCount > 50;
    final chartWidth = needsScrolling ? displayPointCount * 24.0 : double.infinity;

    return Container(
      key: widget.moodChartKey,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with data info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.show_chart_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Trend',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$displayPointCount $aggregationType points',
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$aggregationType Average',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart with Y-axis labels
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis labels (mood scores)
              SizedBox(
                width: 24,
                height: 200,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildYAxisLabel('10', theme),
                    _buildYAxisLabel('8', theme),
                    _buildYAxisLabel('6', theme),
                    _buildYAxisLabel('4', theme),
                    _buildYAxisLabel('2', theme),
                    _buildYAxisLabel('0', theme),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Chart (scrollable if needed)
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: needsScrolling
                          ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: chartWidth,
                          height: 200,
                          child: CustomPaint(
                            painter: MoodChartPainter(
                              dates: sortedDisplayDates,
                              values: displayValues,
                              maxValue: maxMood,
                              color: theme.colorScheme.primary,
                              useSmoothing: aggregationType != 'Daily',
                            ),
                          ),
                        ),
                      )
                          : CustomPaint(
                        painter: MoodChartPainter(
                          dates: sortedDisplayDates,
                          values: displayValues,
                          maxValue: maxMood,
                          color: theme.colorScheme.primary,
                          useSmoothing: aggregationType != 'Daily',
                        ),
                        size: const Size(double.infinity, 200),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // X-axis labels
                    needsScrolling
                        ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: chartWidth,
                        child: _buildXAxisLabelsScrollable(
                            sortedDisplayDates, theme, aggregationType),
                      ),
                    )
                        : _buildXAxisLabels(sortedDisplayDates, theme, aggregationType),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Info and controls
          Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getChartInfoText(aggregationType, dataPointCount, needsScrolling),
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Scroll hint
              if (needsScrolling)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Swipe to explore all data points',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Map<DateTime, double> _aggregateByWeek(List<DateTime> dates, Map<DateTime, double> dayAverages) {
    final Map<DateTime, double> weeklyValues = {};
    final Map<DateTime, List<double>> weeklyGroups = {};

    for (var date in dates) {
      // Get Monday of the week
      final weekStart = date.subtract(Duration(days: date.weekday - 1));
      final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);

      weeklyGroups.putIfAbsent(monday, () => []);
      weeklyGroups[monday]!.add(dayAverages[date]!);
    }

    weeklyGroups.forEach((monday, values) {
      weeklyValues[monday] = values.reduce((a, b) => a + b) / values.length;
    });

    return weeklyValues;
  }

  Map<DateTime, double> _aggregateByMonth(List<DateTime> dates, Map<DateTime, double> dayAverages) {
    final Map<DateTime, double> monthlyValues = {};
    final Map<DateTime, List<double>> monthlyGroups = {};

    for (var date in dates) {
      // Get first day of the month
      final monthStart = DateTime(date.year, date.month, 1);

      monthlyGroups.putIfAbsent(monthStart, () => []);
      monthlyGroups[monthStart]!.add(dayAverages[date]!);
    }

    monthlyGroups.forEach((monthStart, values) {
      monthlyValues[monthStart] = values.reduce((a, b) => a + b) / values.length;
    });

    return monthlyValues;
  }

  String _getChartInfoText(String aggregationType, int originalCount, bool needsScrolling) {
    if (aggregationType == 'Monthly') {
      return 'Showing monthly averages from $originalCount days of data for clearer long-term trends';
    } else if (aggregationType == 'Weekly') {
      return 'Showing weekly averages from $originalCount days of data for better clarity';
    } else {
      if (needsScrolling) {
        return 'Showing daily averages - swipe chart to explore all $originalCount data points';
      } else {
        return 'Each point shows your daily average mood';
      }
    }
  }

  Widget _buildYAxisLabel(String label, ThemeData theme) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildXAxisLabels(List<DateTime> dates, ThemeData theme, String aggregationType) {
    if (dates.isEmpty) return const SizedBox.shrink();

    final indicesToShow = _getDateIndicesToShow(dates.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: indicesToShow.map((index) {
        if (index >= dates.length) return const SizedBox.shrink();

        final date = dates[index];
        final label = _formatDateLabel(date, aggregationType);

        return Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: index == 0
                ? TextAlign.start
                : (index == dates.length - 1
                ? TextAlign.end
                : TextAlign.center),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildXAxisLabelsScrollable(List<DateTime> dates, ThemeData theme, String aggregationType) {
    if (dates.isEmpty) return const SizedBox.shrink();

    // Show more labels when scrollable - every 5th point or so
    final step = (dates.length / 10).ceil().clamp(1, 10);
    final indicesToShow = <int>[];

    for (int i = 0; i < dates.length; i += step) {
      indicesToShow.add(i);
    }
    // Always include the last index
    if (indicesToShow.last != dates.length - 1) {
      indicesToShow.add(dates.length - 1);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(dates.length, (index) {
        if (!indicesToShow.contains(index)) {
          return SizedBox(width: 24.0);
        }

        final date = dates[index];
        final label = _formatDateLabel(date, aggregationType);

        return SizedBox(
          width: 24.0,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        );
      }),
    );
  }

  String _formatDateLabel(DateTime date, String aggregationType) {
    if (aggregationType == 'Monthly') {
      return DateFormat('MMM\nyy').format(date);
    } else if (aggregationType == 'Weekly') {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('M/d').format(date);
    }
  }

  List<int> _getDateIndicesToShow(int totalDates) {
    if (totalDates <= 3) {
      return List.generate(totalDates, (i) => i);
    } else {
      return [0, totalDates ~/ 2, totalDates - 1];
    }
  }

  Widget _buildActivityCalendar(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Determine calendar style based on selected range
    final isLongRange = _selectedRange == 'Year' || _selectedRange == 'Lifetime' || _selectedRange == 'YTD';

    // Check if custom range is long (more than 90 days)
    final isCustomLongRange = _selectedRange == 'Custom' &&
        _customStartDate != null &&
        _customEndDate != null &&
        _customEndDate!.difference(_customStartDate!).inDays > 90;

    if (isLongRange || isCustomLongRange) {
      return _buildGridCalendar(theme, entries);
    } else {
      return _buildLinearCalendar(theme, entries);
    }
  }

  Widget _buildLinearCalendar(ThemeData theme, List<MoodEntry> entries) {
    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;

    // Handle custom date range
    if (_selectedRange == 'Custom' && _customStartDate != null && _customEndDate != null) {
      startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day);
    } else {
      // Default behavior for preset ranges
      int daysToShow = 7; // Initialize with default value

      switch (_selectedRange) {
        case '7D':
          daysToShow = 7;
          break;
        case '30D':
          daysToShow = 30;
          break;
        case '3M':
          daysToShow = 90;
          break;
        case 'YTD':
        // Year to date - from Jan 1 to today
          startDate = DateTime(now.year, 1, 1);
          endDate = DateTime(now.year, now.month, now.day);
          daysToShow = -1; // Flag to use calculated dates
          break;
        case 'Custom':
        // Custom selected but no dates - show last 7 days
          daysToShow = 7;
          break;
        default:
          daysToShow = 7;
      }

      if (daysToShow > 0) {
        endDate = DateTime(now.year, now.month, now.day);
        startDate = endDate.subtract(Duration(days: daysToShow - 1));
      }
    }

    // Count entries per day
    final Map<DateTime, int> dailyCounts = {};
    for (var entry in entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    // Group dates by month
    final Map<String, List<DateTime>> monthGroups = {};
    DateTime current = startDate;
    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      final monthKey = DateFormat('MMMM yyyy').format(current);
      monthGroups.putIfAbsent(monthKey, () => []);
      monthGroups[monthKey]!.add(current);
      current = current.add(const Duration(days: 1));
    }

    return Container(
      key: widget.activityKey,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Calendar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedRange == 'Custom' && _customStartDate != null && _customEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Build calendar for each month
          ...monthGroups.entries.map((monthEntry) {
            final monthName = monthEntry.key;
            final dates = monthEntry.value;

            // Build weeks for this month
            final weeks = <List<DateTime?>>[];
            List<DateTime?> currentWeek = List.filled(7, null);

            for (var date in dates) {
              final weekday = date.weekday - 1; // Monday = 0, Sunday = 6

              // If we're starting a new week and current week has content
              if (weekday == 0 && currentWeek.any((d) => d != null)) {
                weeks.add(List.from(currentWeek));
                currentWeek = List.filled(7, null);
              }

              currentWeek[weekday] = date;

              // If it's Sunday or the last date
              if (weekday == 6 || date == dates.last) {
                weeks.add(List.from(currentWeek));
                if (date != dates.last) {
                  currentWeek = List.filled(7, null);
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Month name
                  Text(
                    monthName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Weekday headers
                  Row(
                    children: ['M', 'T', 'W', 'T', 'F', 'S', 'S'].map((day) {
                      return Expanded(
                        child: Center(
                          child: Text(
                            day,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),

                  // Week rows
                  ...weeks.map((week) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: week.map((date) {
                          if (date == null) {
                            return Expanded(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(),
                              ),
                            );
                          }

                          final count = dailyCounts[date] ?? 0;
                          final isDark = theme.brightness == Brightness.dark;
                          Color boxColor;
                          Color? borderColor;
                          if (count == 0) {
                            // Empty boxes: light fill with strong border for definition
                            boxColor = isDark
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                                : Colors.grey[200]!;
                            borderColor = isDark
                                ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                : Colors.grey[400];
                          } else if (count == 1) {
                            boxColor = theme.colorScheme.primary.withValues(alpha: 0.3);
                          } else if (count == 2) {
                            boxColor = theme.colorScheme.primary.withValues(alpha: 0.6);
                          } else {
                            boxColor = theme.colorScheme.primary;
                          }

                          final isToday = date.year == now.year &&
                              date.month == now.month &&
                              date.day == now.day;

                          return Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: boxColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isToday
                                      ? Border.all(
                                    color: theme.colorScheme.primary,
                                    width: 2,
                                  )
                                      : borderColor != null
                                      ? Border.all(color: borderColor, width: 1)
                                      : null,
                                ),
                                child: Center(
                                  child: Text(
                                    date.day.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                                      color: count > 0
                                          ? Colors.white
                                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 6),
              _buildLegendBox(
                Colors.transparent,
                borderColor: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                    : Colors.grey[300],
              ),
              _buildLegendBox(theme.colorScheme.primary.withValues(alpha: 0.3)),
              _buildLegendBox(theme.colorScheme.primary.withValues(alpha: 0.6)),
              _buildLegendBox(theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCalendar(ThemeData theme, List<MoodEntry> entries) {
    final now = DateTime.now();
    DateTime startDate;
    DateTime endDate;

    // Handle custom date range
    if (_selectedRange == 'Custom' && _customStartDate != null && _customEndDate != null) {
      startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day);
    } else if (_selectedRange == 'Year') {
      // Full current calendar year
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, 12, 31);
    } else if (_selectedRange == 'YTD') {
      // Rolling 12 months ending today
      startDate = DateTime(now.year - 1, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day);
    } else if (_selectedRange == 'Lifetime') {
      // Lifetime - all data
      startDate = entries.isNotEmpty ? entries.last.timestamp : now.subtract(const Duration(days: 365));
      endDate = DateTime(now.year, now.month, now.day);
    } else {
      // Fallback
      startDate = entries.isNotEmpty ? entries.last.timestamp : now.subtract(const Duration(days: 365));
      endDate = DateTime(now.year, now.month, now.day);
    }

    // Count entries per day
    final Map<DateTime, int> dailyCounts = {};
    for (var entry in entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
    }

    // Group months by year
    final Map<int, List<DateTime>> yearGroups = {};
    DateTime currentMonth = DateTime(startDate.year, startDate.month);
    final endMonth = DateTime(endDate.year, endDate.month);

    while (currentMonth.isBefore(endMonth) ||
        (currentMonth.year == endMonth.year && currentMonth.month == endMonth.month)) {
      yearGroups.putIfAbsent(currentMonth.year, () => []);
      yearGroups[currentMonth.year]!.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    }

    // Build the grid separated by years
    return Container(
      key: widget.activityKey,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Activity Calendar',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_selectedRange == 'Custom' && _customStartDate != null && _customEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${DateFormat('MMM d').format(_customStartDate!)} - ${DateFormat('MMM d, yyyy').format(_customEndDate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Build calendar for each year
          ...yearGroups.entries.map((yearEntry) {
            final year = yearEntry.key;
            final months = yearEntry.value;
            final isLastYear = year == yearGroups.keys.last;

            return Padding(
              padding: EdgeInsets.only(bottom: isLastYear ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year label
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      '$year',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),

                  // Month headers and grid
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Day numbers column (left side)
                      SizedBox(
                        width: 24,
                        child: Column(
                          children: [
                            const SizedBox(height: 24), // Space for month headers
                            ...List.generate(31, (dayIndex) {
                              final dayNumber = dayIndex + 1;
                              return Container(
                                height: 14,
                                margin: const EdgeInsets.only(bottom: 2),
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),

                      // Month columns
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: months.map((month) {
                              return SizedBox(
                                width: 24, // Fixed width for square cells
                                child: Column(
                                  children: [
                                    // Month header
                                    SizedBox(
                                      height: 24,
                                      child: Center(
                                        child: Text(
                                          DateFormat('MMM').format(month).substring(0, 1),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Day cells
                                    ...List.generate(31, (dayIndex) {
                                      final dayNumber = dayIndex + 1;
                                      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

                                      if (dayNumber > daysInMonth) {
                                        return Container(
                                          height: 14,
                                          margin: const EdgeInsets.only(bottom: 2),
                                        );
                                      }

                                      final cellDate = DateTime(month.year, month.month, dayNumber);
                                      final count = dailyCounts[cellDate] ?? 0;

                                      final isDark = theme.brightness == Brightness.dark;
                                      Color boxColor;
                                      Color? borderColor;
                                      if (count == 0) {
                                        boxColor = isDark
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                                            : Colors.grey[200]!;
                                        borderColor = isDark
                                            ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                                            : Colors.grey[400];
                                      } else if (count == 1) {
                                        boxColor = theme.colorScheme.primary.withValues(alpha: 0.3);
                                      } else if (count == 2) {
                                        boxColor = theme.colorScheme.primary.withValues(alpha: 0.6);
                                      } else {
                                        boxColor = theme.colorScheme.primary;
                                      }

                                      return Container(
                                        height: 14,
                                        margin: const EdgeInsets.only(bottom: 2, left: 1, right: 1),
                                        decoration: BoxDecoration(
                                          color: boxColor,
                                          borderRadius: BorderRadius.circular(2),
                                          border: borderColor != null
                                              ? Border.all(color: borderColor, width: 1)
                                              : null,
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 6),
              _buildLegendBox(
                theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.08)
                    : Colors.grey[200]!,
                borderColor: theme.brightness == Brightness.dark
                    ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                    : Colors.grey[400],
              ),
              _buildLegendBox(theme.colorScheme.primary.withValues(alpha: 0.3)),
              _buildLegendBox(theme.colorScheme.primary.withValues(alpha: 0.6)),
              _buildLegendBox(theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'More',
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color, {Color? borderColor}) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 0.5)
            : null,
      ),
    );
  }

  Widget _buildMoodDistribution(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Group by mood category
    final Map<String, int> distribution = {
      'Excellent (9-10)': 0,
      'Good (7-8)': 0,
      'Okay (5-6)': 0,
      'Low (3-4)': 0,
      'Struggling (1-2)': 0,
    };

    for (var entry in entries) {
      if (entry.moodRating >= 9) {
        distribution['Excellent (9-10)'] =
            distribution['Excellent (9-10)']! + 1;
      } else if (entry.moodRating >= 7) {
        distribution['Good (7-8)'] = distribution['Good (7-8)']! + 1;
      } else if (entry.moodRating >= 5) {
        distribution['Okay (5-6)'] = distribution['Okay (5-6)']! + 1;
      } else if (entry.moodRating >= 3) {
        distribution['Low (3-4)'] = distribution['Low (3-4)']! + 1;
      } else {
        distribution['Struggling (1-2)'] =
            distribution['Struggling (1-2)']! + 1;
      }
    }

    final total = entries.length;

    return Container(
      key: widget.distributionKey,
      height: 420,
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pie_chart_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Mood Distribution',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: PageView(
              controller: _distributionPageController,
              onPageChanged: (index) {
                setState(() {
                  _currentDistributionPage = index;
                });
              },
              children: [
                _buildDistributionList(theme, distribution, total),
                _buildPieChart(theme, distribution, total),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPageIndicator(theme),
        ],
      ),
    );
  }

  Widget _buildDistributionList(
      ThemeData theme,
      Map<String, int> distribution,
      int total,
      ) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      children: distribution.entries.map((entry) {
        final percentage = ((entry.value / total) * 100).toStringAsFixed(0);
        final label = entry.key.split(' ')[0];
        final color = _getMoodColor(label);

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    entry.key,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.value / total,
                  minHeight: 8,
                  backgroundColor: theme.scaffoldBackgroundColor,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChart(
      ThemeData theme,
      Map<String, int> distribution,
      int total,
      ) {
    final sections = distribution.entries.where((e) => e.value > 0).map((entry) {
      final label = entry.key.split(' ')[0];
      final color = _getMoodColor(label);
      final percentage = (entry.value / total) * 100;

      return PieChartSectionData(
        color: color,
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        radius: 100,
        titleStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 2,
            ),
          ],
        ),
      );
    }).toList();

    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 0,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                touchCallback: (FlTouchEvent event, pieTouchResponse) {
                  setState(() {});
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: distribution.entries.where((e) => e.value > 0).map((entry) {
            final label = entry.key.split(' ')[0];
            final color = _getMoodColor(label);

            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPageIndicator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentDistributionPage == index ? 20 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: _currentDistributionPage == index
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Color _getMoodColor(String label) {
    final gradient = widget.themeService.getMoodGradient();
    switch (label) {
      case 'Excellent':
        return gradient[4]; // 9-10
      case 'Good':
        return gradient[3]; // 7-8
      case 'Okay':
        return gradient[2]; // 5-6
      case 'Low':
        return gradient[1]; // 3-4
      case 'Struggling':
        return gradient[0]; // 1-2
      default:
        return gradient[2];
    }
  }

  Widget _buildInsights(ThemeData theme, List<MoodEntry> entries) {
    final insights = _generateInsights(entries);
    if (insights.isEmpty) return const SizedBox.shrink();

    return Container(
      key: widget.insightsKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      'Personalized observations',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Insights list
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;
            final isLast = index == insights.length - 1;

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: _buildInsightCard(theme, insight, index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildInsightCard(ThemeData theme, String insight, int index) {
    // Determine icon based on insight content
    IconData icon;
    Color iconColor;

    if (insight.contains('improving') || insight.contains('Keep it up')) {
      icon = Icons.trending_up_rounded;
      iconColor = const Color(0xFF4CAF50);
    } else if (insight.contains('lower') || insight.contains('self-care')) {
      icon = Icons.spa_rounded;
      iconColor = const Color(0xFFFF9800);
    } else if (insight.contains('logged') || insight.contains('tracking')) {
      icon = Icons.check_circle_outline_rounded;
      iconColor = theme.colorScheme.primary;
    } else {
      icon = Icons.lightbulb_outline_rounded;
      iconColor = theme.colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon with colored background
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 12),

          // Insight text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  insight,
                  style: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _generateInsights(List<MoodEntry> entries) {
    if (entries.length < 3) return [];

    final insights = <String>[];
    final avgMood =
        entries.fold<int>(0, (sum, e) => sum + e.moodRating) / entries.length;

    // Count unique days
    final uniqueDays = entries
        .map((e) =>
        DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
        .toSet()
        .length;

    // Trend insight
    if (entries.length >= 7) {
      final recentAvg =
          entries.take(7).fold<int>(0, (sum, e) => sum + e.moodRating) / 7;
      if (recentAvg > avgMood + 1) {
        insights
            .add('Your mood has been improving lately! Keep it up! 📈');
      } else if (recentAvg < avgMood - 1) {
        insights.add(
            'Your mood has been lower recently. Consider self-care activities. 💙');
      }
    }

    // Consistency insight with unique days
    insights.add(
        'You\'ve logged ${entries.length} entries across $uniqueDays days. Great tracking! ⭐');

    return insights;
  }

  Map<String, dynamic> _getComparisonData(List<MoodEntry> allEntries, String range) {
    if (allEntries.isEmpty) {
      return {'hasComparison': false};
    }

    final now = DateTime.now();

    // For Year and Lifetime, compare current year vs previous year
    if (range == 'Year' || range == 'Lifetime') {
      final currentYear = now.year;
      final previousYear = currentYear - 1;

      // Current year entries (full year)
      final currentYearEntries = allEntries.where((e) {
        return e.timestamp.year == currentYear;
      }).toList();

      // Previous year entries (full year)
      final previousYearEntries = allEntries.where((e) {
        return e.timestamp.year == previousYear;
      }).toList();

      if (currentYearEntries.isEmpty || previousYearEntries.isEmpty) {
        return {'hasComparison': false};
      }

      final currentAvg = currentYearEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / currentYearEntries.length;
      final previousAvg = previousYearEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / previousYearEntries.length;
      final change = currentAvg - previousAvg;
      final percentChange = (change / previousAvg * 100);

      return {
        'hasComparison': true,
        'currentAvg': currentAvg,
        'previousAvg': previousAvg,
        'change': change,
        'percentChange': percentChange,
        'currentCount': currentYearEntries.length,
        'previousCount': previousYearEntries.length,
        'isYearlyComparison': true,
        'currentYear': currentYear,
        'previousYear': previousYear,
      };
    }

    // For YTD, compare rolling 12 months vs previous 12 months
    if (range == 'YTD') {
      final today = DateTime(now.year, now.month, now.day);
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);
      final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);

      // Current YTD entries (past 12 months)
      final currentYTDEntries = allEntries.where((e) {
        final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        return (entryDate.isAfter(oneYearAgo) || entryDate.isAtSameMomentAs(oneYearAgo)) &&
            (entryDate.isBefore(today) || entryDate.isAtSameMomentAs(today));
      }).toList();

      // Previous 12 months
      final previousYTDEntries = allEntries.where((e) {
        final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        return (entryDate.isAfter(twoYearsAgo) || entryDate.isAtSameMomentAs(twoYearsAgo)) &&
            entryDate.isBefore(oneYearAgo);
      }).toList();

      if (currentYTDEntries.isEmpty || previousYTDEntries.isEmpty) {
        return {'hasComparison': false};
      }

      final currentAvg = currentYTDEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / currentYTDEntries.length;
      final previousAvg = previousYTDEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / previousYTDEntries.length;
      final change = currentAvg - previousAvg;
      final percentChange = (change / previousAvg * 100);

      return {
        'hasComparison': true,
        'currentAvg': currentAvg,
        'previousAvg': previousAvg,
        'change': change,
        'percentChange': percentChange,
        'currentCount': currentYTDEntries.length,
        'previousCount': previousYTDEntries.length,
        'isYearlyComparison': true,
        'currentYear': 'Past 12 mo',
        'previousYear': 'Prior 12 mo',
      };
    }

    // For other ranges, use period-over-period comparison
    int days;

    switch (range) {
      case '7D':
        days = 7;
        break;
      case '30D':
        days = 30;
        break;
      case '3M':
        days = 90;
        break;
      default:
        days = 7;
    }

    // Current period
    final currentCutoff = now.subtract(Duration(days: days));
    final currentEntries = allEntries.where((e) {
      final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      return entryDate.isAfter(DateTime(currentCutoff.year, currentCutoff.month, currentCutoff.day)) ||
          entryDate.isAtSameMomentAs(DateTime(currentCutoff.year, currentCutoff.month, currentCutoff.day));
    }).toList();

    // Previous period
    final previousStart = currentCutoff.subtract(Duration(days: days));
    final previousEnd = currentCutoff;
    final previousEntries = allEntries.where((e) {
      final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      final startDate = DateTime(previousStart.year, previousStart.month, previousStart.day);
      final endDate = DateTime(previousEnd.year, previousEnd.month, previousEnd.day);
      return (entryDate.isAfter(startDate) || entryDate.isAtSameMomentAs(startDate)) &&
          entryDate.isBefore(endDate);
    }).toList();

    if (currentEntries.isEmpty || previousEntries.isEmpty) {
      return {'hasComparison': false};
    }

    final currentAvg = currentEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / currentEntries.length;
    final previousAvg = previousEntries.fold<int>(0, (sum, e) => sum + e.moodRating) / previousEntries.length;
    final change = currentAvg - previousAvg;
    final percentChange = (change / previousAvg * 100);

    return {
      'hasComparison': true,
      'currentAvg': currentAvg,
      'previousAvg': previousAvg,
      'change': change,
      'percentChange': percentChange,
      'currentCount': currentEntries.length,
      'previousCount': previousEntries.length,
      'isYearlyComparison': false,
    };
  }

  Widget _buildComparisonCard(ThemeData theme, Map<String, dynamic> comparisonData) {
    if (!comparisonData['hasComparison']) {
      return const SizedBox.shrink();
    }

    final currentAvg = comparisonData['currentAvg'] as double;
    final previousAvg = comparisonData['previousAvg'] as double;
    final change = comparisonData['change'] as double;
    final percentChange = comparisonData['percentChange'] as double;
    final currentCount = comparisonData['currentCount'] as int;
    final previousCount = comparisonData['previousCount'] as int;
    final isYearlyComparison = comparisonData['isYearlyComparison'] ?? false;

    final isImprovement = change > 0;
    final isSignificantChange = change.abs() >= 0.5;

    Color changeColor;
    IconData changeIcon;
    String changeText;

    if (!isSignificantChange) {
      changeColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
      changeIcon = Icons.trending_flat_rounded;
      changeText = 'Stable';
    } else if (isImprovement) {
      changeColor = const Color(0xFF4CAF50); // Green
      changeIcon = Icons.trending_up_rounded;
      changeText = 'Improving';
    } else {
      changeColor = const Color(0xFFFF9800); // Orange
      changeIcon = Icons.trending_down_rounded;
      changeText = 'Declining';
    }

    String periodLabel;
    String currentPeriodLabel;
    String previousPeriodLabel;

    if (isYearlyComparison) {
      final currentYearValue = comparisonData['currentYear'];
      final previousYearValue = comparisonData['previousYear'];

      // Handle both int (for Year filter) and String (for YTD filter)
      final currentYearLabel = currentYearValue is int ? currentYearValue.toString() : currentYearValue as String;
      final previousYearLabel = previousYearValue is int ? previousYearValue.toString() : previousYearValue as String;

      if (_selectedRange == 'YTD') {
        periodLabel = 'Past 12 Months vs Prior 12 Months';
        currentPeriodLabel = currentYearLabel;
        previousPeriodLabel = previousYearLabel;
      } else {
        periodLabel = '$currentYearLabel vs $previousYearLabel';
        currentPeriodLabel = currentYearLabel;
        previousPeriodLabel = previousYearLabel;
      }
    } else {
      switch (_selectedRange) {
        case '7D':
          periodLabel = 'Last 7 Days vs Previous 7 Days';
          currentPeriodLabel = 'Current Period';
          previousPeriodLabel = 'Previous Period';
          break;
        case '30D':
          periodLabel = 'Last 30 Days vs Previous 30 Days';
          currentPeriodLabel = 'Current Period';
          previousPeriodLabel = 'Previous Period';
          break;
        case '3M':
          periodLabel = 'Last 3 Months vs Previous 3 Months';
          currentPeriodLabel = 'Current Period';
          previousPeriodLabel = 'Previous Period';
          break;
        default:
          periodLabel = 'Comparison';
          currentPeriodLabel = 'Current Period';
          previousPeriodLabel = 'Previous Period';
      }
    }

    return Container(
      key: widget.comparisonKey,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.08),
            theme.colorScheme.secondary.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.compare_arrows_rounded,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Period Comparison',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            periodLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentPeriodLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          currentAvg.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          '/10',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$currentCount ${currentCount == 1 ? 'entry' : 'entries'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: changeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: changeColor.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      changeIcon,
                      color: changeColor,
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: changeColor,
                      ),
                    ),
                    Text(
                      '${percentChange.abs().toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 11,
                        color: changeColor.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previousPeriodLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          previousAvg.toStringAsFixed(1),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        Text(
                          '/10',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$previousCount ${previousCount == 1 ? 'entry' : 'entries'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isSignificantChange) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    isImprovement ? Icons.emoji_emotions_rounded : Icons.self_improvement_rounded,
                    size: 18,
                    color: changeColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isImprovement
                          ? 'Great progress! Your mood is ${changeText.toLowerCase()}.'
                          : 'Consider self-care activities to boost your mood.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: changeColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<MoodEntry> _getEntriesForRange(
      List<MoodEntry> allEntries, String range) {
    AppLogger.debug('Filtering entries for range: $range', tag: 'TrendsScreen.Filter');
    AppLogger.data('Input entries count', details: '${allEntries.length}', tag: 'TrendsScreen.Filter');

    if (allEntries.isEmpty) {
      AppLogger.warning('No entries to filter!', tag: 'TrendsScreen.Filter');
      return [];
    }

    final now = DateTime.now();
    AppLogger.debug('Current time: $now', tag: 'TrendsScreen.Filter');

    // Handle custom date range
    if (range == 'Custom' && _customStartDate != null && _customEndDate != null) {
      final startDate = DateTime(_customStartDate!.year, _customStartDate!.month, _customStartDate!.day);
      final endDate = DateTime(_customEndDate!.year, _customEndDate!.month, _customEndDate!.day);

      final filtered = allEntries.where((e) {
        final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        return (entryDate.isAfter(startDate) || entryDate.isAtSameMomentAs(startDate)) &&
            (entryDate.isBefore(endDate) || entryDate.isAtSameMomentAs(endDate));
      }).toList();

      AppLogger.success('Custom range: ${filtered.length} entries between $startDate and $endDate', tag: 'TrendsScreen.Filter');
      return filtered;
    }

    // Handle YTD (Year to Date) - Rolling 12 months ending today
    if (range == 'YTD') {
      final today = DateTime(now.year, now.month, now.day);
      final oneYearAgo = DateTime(now.year - 1, now.month, now.day);

      final filtered = allEntries.where((e) {
        final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        return (entryDate.isAfter(oneYearAgo) || entryDate.isAtSameMomentAs(oneYearAgo)) &&
            (entryDate.isBefore(today) || entryDate.isAtSameMomentAs(today));
      }).toList();

      AppLogger.success('YTD: ${filtered.length} entries from $oneYearAgo to $today', tag: 'TrendsScreen.Filter');
      return filtered;
    }

    // Handle full Year (current calendar year Jan 1 - Dec 31)
    if (range == 'Year') {
      final startOfYear = DateTime(now.year, 1, 1);
      final endOfYear = DateTime(now.year, 12, 31);

      final filtered = allEntries.where((e) {
        final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
        return (entryDate.isAfter(startOfYear) || entryDate.isAtSameMomentAs(startOfYear)) &&
            (entryDate.isBefore(endOfYear) || entryDate.isAtSameMomentAs(endOfYear));
      }).toList();

      AppLogger.success('Year: ${filtered.length} entries from $startOfYear to $endOfYear', tag: 'TrendsScreen.Filter');
      return filtered;
    }

    // Handle Lifetime
    if (range == 'Lifetime') {
      AppLogger.success('Lifetime selected - returning all ${allEntries.length} entries',
          tag: 'TrendsScreen.Filter'
      );
      return allEntries;
    }

    DateTime cutoff;

    switch (range) {
      case '7D':
        cutoff = now.subtract(const Duration(days: 7));
        break;
      case '30D':
        cutoff = now.subtract(const Duration(days: 30));
        break;
      case '3M':
        cutoff = now.subtract(const Duration(days: 90));
        break;
      case 'Custom':
      // If custom is selected but no dates set, return empty
        AppLogger.warning('Custom range selected but no dates set', tag: 'TrendsScreen.Filter');
        return [];
      default:
        cutoff = now.subtract(const Duration(days: 7));
    }

    final cutoffDate = DateTime(cutoff.year, cutoff.month, cutoff.day);
    AppLogger.info('Cutoff date (normalized): $cutoffDate', tag: 'TrendsScreen.Filter');

    final filtered = allEntries.where((e) {
      final entryDate = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      final isAfterCutoff = entryDate.isAfter(cutoffDate);
      final isSameAsCutoff = entryDate.isAtSameMomentAs(cutoffDate);
      final included = isAfterCutoff || isSameAsCutoff;

      // Log first 3 entries for debugging
      if (allEntries.indexOf(e) < 3) {
        AppLogger.prettyPrint({
          'Entry timestamp': e.timestamp.toString(),
          'Entry date (normalized)': entryDate.toString(),
          'Is after cutoff?': isAfterCutoff.toString(),
          'Is same as cutoff?': isSameAsCutoff.toString(),
          'Included?': included.toString(),
        }, title: 'Entry Check ${allEntries.indexOf(e)}', tag: 'TrendsScreen.Filter');
      }

      return included;
    }).toList();

    AppLogger.success('Filtered to ${filtered.length} entries', tag: 'TrendsScreen.Filter');

    return filtered;
  }

  String? _calculatePeakHour(List<MoodEntry> entries) {
    if (entries.isEmpty) return null;

    final Map<int, List<int>> hourlyMoods = {};

    for (var entry in entries) {
      final hour = entry.timestamp.hour;
      hourlyMoods[hour] = (hourlyMoods[hour] ?? [])..add(entry.moodRating);
    }

    if (hourlyMoods.isEmpty) return null;

    int peakHour = 0;
    double highestAvg = 0;

    hourlyMoods.forEach((hour, moods) {
      final avg = moods.reduce((a, b) => a + b) / moods.length;
      if (avg > highestAvg) {
        highestAvg = avg;
        peakHour = hour;
      }
    });

    final period = peakHour >= 12 ? 'PM' : 'AM';
    final displayHour =
    peakHour > 12 ? peakHour - 12 : (peakHour == 0 ? 12 : peakHour);

    return '$displayHour $period';
  }
}

class MoodChartPainter extends CustomPainter {
  final List<DateTime> dates;
  final Map<DateTime, double> values;
  final double maxValue;
  final Color color;
  final bool useSmoothing;

  MoodChartPainter({
    required this.dates,
    required this.values,
    required this.maxValue,
    required this.color,
    this.useSmoothing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (dates.isEmpty || size.width <= 0 || size.height <= 0) return;

    // Area fill paint
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    // Line paint
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = useSmoothing ? 3.0 : 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Grid paint
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw horizontal grid lines
    for (int i = 0; i <= 5; i++) {
      final y = (size.height / 5) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    final path = Path();
    final linePath = Path();

    final stepX =
    dates.length > 1 ? size.width / (dates.length - 1) : size.width / 2;

    // Create points
    final points = <Offset>[];
    for (int i = 0; i < dates.length; i++) {
      final x = i * stepX;
      final value = values[dates[i]] ?? 0;
      final normalizedValue = (value / maxValue).clamp(0.0, 1.0);
      final y = size.height - (normalizedValue * size.height);

      points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // Build paths
    path.moveTo(points.first.dx, size.height);
    linePath.moveTo(points.first.dx, points.first.dy);

    if (useSmoothing && points.length > 2) {
      // Smooth curve for longer periods
      for (int i = 0; i < points.length - 1; i++) {
        final current = points[i];
        final next = points[i + 1];
        final controlX = (current.dx + next.dx) / 2;

        path.quadraticBezierTo(controlX, current.dy, next.dx, next.dy);
        linePath.quadraticBezierTo(controlX, current.dy, next.dx, next.dy);
      }
    } else {
      // Straight lines for shorter periods
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
        linePath.lineTo(points[i].dx, points[i].dy);
      }
    }

    path.lineTo(points.last.dx, size.height);
    path.close();

    // Draw filled area and line
    canvas.drawPath(path, paint);
    canvas.drawPath(linePath, linePaint);

    // Draw data points
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var point in points) {
      canvas.drawCircle(point, 4, dotPaint);
      canvas.drawCircle(
        point,
        3,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(MoodChartPainter oldDelegate) {
    return oldDelegate.dates != dates ||
        oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.color != color ||
        oldDelegate.useSmoothing != useSmoothing;
  }
}