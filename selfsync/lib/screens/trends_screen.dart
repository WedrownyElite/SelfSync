import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/mood_entry.dart';
import '../services/mood_service.dart';
import '../widgets/side_drawer.dart';
import '../utils/app_logger.dart';
import '../services/theme_service.dart';

class TrendsScreen extends StatefulWidget {
  final MoodService moodService;
  final Function(int tabIndex, DateTime? date)? onNavigateToTab;
  final SideDrawerController drawerController;
  final ThemeService themeService;

  const TrendsScreen({
    super.key,
    required this.moodService,
    this.onNavigateToTab,
    required this.drawerController,
    required this.themeService,
  });

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  String _selectedRange = '7D';
  final PageController _distributionPageController = PageController();
  int _currentDistributionPage = 0;

  @override
  void initState() {
    super.initState();
    // Listen to mood service changes
    widget.moodService.addListener(_onMoodServiceUpdate);
    AppLogger.lifecycle('Started listening to MoodService updates', tag: 'TrendsScreen');
  }

  @override
  void dispose() {
    widget.moodService.removeListener(_onMoodServiceUpdate);
    _distributionPageController.dispose();
    AppLogger.lifecycle('Stopped listening to MoodService updates', tag: 'TrendsScreen');
    super.dispose();
  }

  void _onMoodServiceUpdate() {
    if (mounted) {
      AppLogger.debug('MoodService update received, rebuilding UI', tag: 'TrendsScreen');
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
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
            // Show time range selector if there's ANY data at all
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
                padding: const EdgeInsets.all(16),
                children: [
                  const SizedBox(height: 8),
                  _buildInsights(theme, entries),
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
          // ADD HAMBURGER BUTTON
          HamburgerMenuButton(controller: widget.drawerController),
          const SizedBox(width: 12),

          // EXISTING CODE BELOW
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 64,
                color: theme.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 24),
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
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_today_rounded,
                size: 64,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No data for this time range',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
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
    final ranges = ['7D', '30D', '3M', '1Y', 'Lifetime'];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ranges.map((range) {
          final isSelected = _selectedRange == range;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                // Use AppLogger instead of print
                AppLogger.info(
                    'Time range changed: $_selectedRange → $range',
                    tag: 'TrendsScreen.Selector'
                );
                setState(() => _selectedRange = range);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatsGrid(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final avgMood = entries.fold<int>(0, (sum, e) => sum + e.moodRating) /
        entries.length;

    // Find best and toughest days
    final bestEntry = entries.reduce((a, b) => a.moodRating > b.moodRating ? a : b);
    final toughestEntry = entries.reduce((a, b) => a.moodRating < b.moodRating ? a : b);

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          theme,
          'Average Mood',
          avgMood.toStringAsFixed(1),
          Icons.sentiment_satisfied_alt_rounded,
          null,
        ),
        _buildStatCard(
          theme,
          'Peak Time',
          _calculatePeakHour(entries) ?? 'N/A',
          Icons.schedule_rounded,
          null,
        ),
        _buildStatCard(
          theme,
          'Best Day',
          _formatBestDayWithDate(bestEntry),
          Icons.emoji_emotions_rounded,
              () => _navigateToDiary(bestEntry.timestamp),
        ),
        _buildStatCard(
          theme,
          'Toughest Day',
          _formatToughestDayWithDate(toughestEntry),
          Icons.mood_bad_rounded,
              () => _navigateToDiary(toughestEntry.timestamp),
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

  Widget _buildMoodChart(ThemeData theme, List<MoodEntry> entries) {
    if (entries.isEmpty) return const SizedBox.shrink();

    // Check if we should use aggregated data (for 3M or more)
    final useAggregatedData = _selectedRange == '3M' ||
        _selectedRange == '1Y' ||
        _selectedRange == 'Lifetime';

    // Calculate daily averages
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

    // Get sorted dates and values
    final sortedDates = dayAverages.keys.toList()..sort();

    // For longer periods, aggregate by week
    final Map<DateTime, double> displayValues;
    if (useAggregatedData && sortedDates.length > 30) {
      displayValues = <DateTime, double>{};
      final Map<DateTime, List<double>> weeklyValues = {};

      for (var date in sortedDates) {
        // Get Monday of the week
        final weekStart = date.subtract(Duration(days: date.weekday - 1));
        final monday = DateTime(weekStart.year, weekStart.month, weekStart.day);

        weeklyValues.putIfAbsent(monday, () => []);
        weeklyValues[monday]!.add(dayAverages[date]!);
      }

      weeklyValues.forEach((monday, values) {
        displayValues[monday] =
            values.reduce((a, b) => a + b) / values.length;
      });
    } else {
      displayValues = dayAverages;
    }

    // Update sorted dates with the aggregated keys
    final sortedDisplayDates = displayValues.keys.toList()..sort();
    final maxMood = 10.0;

    return Container(
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
                  Text(
                    'Mood Trend',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                useAggregatedData
                    ? 'Weekly Average'
                    : 'Daily Average',
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Chart with Y-axis labels
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Y-axis labels (mood scores) - reduced width
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

              // Chart
              Expanded(
                child: Column(
                  children: [
                    SizedBox(
                      height: 200,
                      child: CustomPaint(
                        painter: MoodChartPainter(
                          dates: sortedDisplayDates,
                          values: displayValues,
                          maxValue: maxMood,
                          color: theme.colorScheme.primary,
                          useSmoothing: useAggregatedData,
                        ),
                        size: const Size(double.infinity, 200),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // X-axis labels (dates)
                    _buildXAxisLabels(sortedDisplayDates, theme),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Additional info
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
                    useAggregatedData
                        ? 'Longer periods show weekly averages for clearer trends'
                        : 'Each point shows your daily average mood',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildXAxisLabels(List<DateTime> dates, ThemeData theme) {
    if (dates.isEmpty) return const SizedBox.shrink();

    final indicesToShow = _getDateIndicesToShow(dates.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: indicesToShow.map((index) {
        if (index >= dates.length) return const SizedBox.shrink();

        final date = dates[index];
        return Expanded(
          child: Text(
            DateFormat('MMM d').format(date),
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
    final isLongRange = _selectedRange == '1Y' || _selectedRange == 'Lifetime';

    if (isLongRange) {
      return _buildGridCalendar(theme, entries);
    } else {
      return _buildLinearCalendar(theme, entries);
    }
  }

  Widget _buildLinearCalendar(ThemeData theme, List<MoodEntry> entries) {
    final now = DateTime.now();
    int daysToShow;

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
      default:
        daysToShow = 7;
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

    // Generate list of dates
    final endDate = DateTime(now.year, now.month, now.day);
    final startDate = endDate.subtract(Duration(days: daysToShow - 1));

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
              Text(
                'Activity Calendar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridCalendar(ThemeData theme, List<MoodEntry> entries) {
    final now = DateTime.now();
    final startDate = _selectedRange == '1Y'
        ? DateTime(now.year - 1, now.month, now.day)
        : (entries.isNotEmpty ? entries.last.timestamp : now.subtract(const Duration(days: 365)));

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

    // Determine which months to show
    final months = <DateTime>[];
    DateTime currentMonth = DateTime(startDate.year, startDate.month);
    final endMonth = DateTime(now.year, now.month);

    while (currentMonth.isBefore(endMonth) ||
        (currentMonth.year == endMonth.year && currentMonth.month == endMonth.month)) {
      months.add(currentMonth);
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
    }

    // Build the grid: rows = days (1-31), columns = months
    return Container(
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
              Text(
                'Activity Calendar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Month headers (J F M A M J J A S O N D)
          Row(
            children: [
              const SizedBox(width: 24), // Space for day numbers
              ...months.map((month) {
                return Expanded(
                  child: Center(
                    child: Text(
                      DateFormat('MMM').format(month).substring(0, 1), // First letter
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 8),

          // Day rows (1-31)
          ...List.generate(31, (dayIndex) {
            final dayNumber = dayIndex + 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  // Day number
                  SizedBox(
                    width: 24,
                    child: Text(
                      '$dayNumber',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  // Month cells
                  ...months.map((month) {
                    // Check if this day exists in this month
                    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

                    if (dayNumber > daysInMonth) {
                      // Day doesn't exist in this month
                      return Expanded(
                        child: Container(
                          height: 14,
                          margin: const EdgeInsets.all(1),
                        ),
                      );
                    }

                    // Get the date for this cell
                    final cellDate = DateTime(month.year, month.month, dayNumber);
                    final count = dailyCounts[cellDate] ?? 0;

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

                    return Expanded(
                      child: Container(
                        height: 14,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: boxColor,
                          borderRadius: BorderRadius.circular(2),
                          border: borderColor != null
                              ? Border.all(color: borderColor, width: 1)
                              : null,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Less',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
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

    return Column(
      children: insights
          .map((insight) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: theme.colorScheme.primary,
                weight: 600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                insight,
                style: TextStyle(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ))
          .toList(),
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
      case '1Y':
        cutoff = now.subtract(const Duration(days: 365));
        break;
      case 'Lifetime':
        AppLogger.success('Lifetime selected - returning all ${allEntries.length} entries',
            tag: 'TrendsScreen.Filter'
        );
        return allEntries;
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