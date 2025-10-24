import 'package:flutter/material.dart';
import '../services/mood_service.dart';
import '../models/mood_entry.dart';
import 'package:intl/intl.dart';
import '../widgets/side_drawer.dart';
import '../services/theme_service.dart';

enum DisplayMode {
  normal,
  circle,
  condensed,
}

enum ColorStyle {
  solid,
  gradient,
}

class CalendarScreen extends StatefulWidget {
  final MoodService moodService;
  final Function(DateTime)? onDateSelected;
  final SideDrawerController drawerController;
  final ThemeService themeService;

  const CalendarScreen({
    super.key,
    required this.moodService,
    this.onDateSelected,
    required this.drawerController,
    required this.themeService,
  });

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final int currentYear = DateTime.now().year;

  // Cache for mood data
  Map<String, _DayMoodData> _moodCache = {};
  bool _needsRebuild = false;

  // Display mode
  DisplayMode _displayMode = DisplayMode.normal;
  ColorStyle _colorStyle = ColorStyle.solid;
  bool _isModePickerExpanded = false;

  // Pre-calculated month data
  late List<_MonthData> _monthsData;

  // Scroll position tracking
  static double? _savedScrollPosition;
  static bool _hasVisitedBefore = false;
  bool _hasScrolledToCurrentMonth = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();

    // Pre-calculate all month data
    _monthsData = List.generate(12, (index) {
      final month = index + 1;
      return _MonthData(
        month: month,
        year: currentYear,
        days: _getDaysInMonth(currentYear, month),
        startingWeekday: _getStartingWeekday(currentYear, month),
        monthName: DateFormat('MMMM').format(DateTime(currentYear, month)),
      );
    });

    _buildMoodCache();
    widget.moodService.addListener(_onMoodServiceUpdate);
    widget.themeService.addListener(_onThemeChanged);

    // Scroll to position after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeScrollPosition();
    });

    // Save scroll position when scrolling
    _scrollController.addListener(_saveScrollPosition);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_saveScrollPosition);
    _scrollController.dispose();
    widget.moodService.removeListener(_onMoodServiceUpdate);
    widget.themeService.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _saveScrollPosition() {
    if (_scrollController.hasClients) {
      _savedScrollPosition = _scrollController.position.pixels;
    }
  }

  void _initializeScrollPosition() {
    if (!_scrollController.hasClients) return;

    if (_hasVisitedBefore && _savedScrollPosition != null) {
      // Restore previous scroll position
      _scrollController.jumpTo(_savedScrollPosition!);
    } else if (!_hasScrolledToCurrentMonth) {
      // First visit - scroll to current month
      _scrollToCurrentMonth();
      _hasVisitedBefore = true;
      _hasScrolledToCurrentMonth = true;
    }
  }

  void _scrollToCurrentMonth() {
    if (!_scrollController.hasClients) return;

    final currentMonth = DateTime.now().month;

    // Wait a bit longer for layout to complete and get accurate measurements
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // Calculate more accurate position
      // Month header: ~16 (top padding) + ~20 (title height) + ~12 (bottom padding) = ~48px
      // Calendar grid varies by weeks in month (typically 4-6 weeks)
      // Week row: ~40px (cell height) + ~8px (bottom padding) = ~48px per week
      // Month bottom margin: ~16px
      // Total per month: ~48 (header) + (weeks * 48) + 16 ≈ 64 + (weeks * 48)

      double totalHeight = 0;

      // Calculate height for all months before current month
      for (int i = 0; i < currentMonth - 1; i++) {
        final monthData = _monthsData[i];
        final totalDays = monthData.startingWeekday + monthData.days.length;
        final weeks = (totalDays / 7).ceil();

        // Month header + (weeks * row height) + bottom margin
        final monthHeight = 48 + (weeks * 48) + 16;
        totalHeight += monthHeight;
      }

      // Scroll to position, ensuring we don't go past max
      final maxScroll = _scrollController.position.maxScrollExtent;
      final targetScroll = (totalHeight - 50).clamp(0.0, maxScroll); // -50 to show a bit of previous month

      _scrollController.animateTo(
        targetScroll,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  List<DateTime> _getDaysInMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    return List.generate(
      lastDay.day,
          (i) => DateTime(year, month, i + 1),
      growable: false,
    );
  }

  int _getStartingWeekday(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday - 1;
  }

  void _onMoodServiceUpdate() {
    if (!mounted) return;

    _needsRebuild = true;
    // Increased debounce for better performance
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted && _needsRebuild) {
        _buildMoodCache();
        if (mounted) {
          setState(() {
            _needsRebuild = false;
          });
        }
      }
    });
  }

  void _onThemeChanged() {
    if (!mounted) return;

    // Rebuild mood cache with new colors from the new gradient
    _buildMoodCache();
    if (mounted) {
      setState(() {});
    }
  }

  void _buildMoodCache() {
    final newCache = <String, _DayMoodData>{};

    // Group entries by date
    for (var entry in widget.moodService.entries) {
      if (entry.timestamp.year != currentYear) continue;

      final key =
          '${entry.timestamp.year}-${entry.timestamp.month}-${entry.timestamp.day}';

      if (!newCache.containsKey(key)) {
        newCache[key] = _DayMoodData(
          date: DateTime(entry.timestamp.year, entry.timestamp.month,
              entry.timestamp.day),
          entries: [],
        );
      }

      newCache[key]!.entries.add(entry);
    }

    // Calculate averages and colors once
    for (var data in newCache.values) {
      final sum = data.entries.fold<int>(0, (sum, e) => sum + e.moodRating);
      data.averageMood = sum / data.entries.length;
      data.emoji = MoodEntry.getMoodEmoji(data.averageMood.round());
      data.solidColor = _getMoodColorForAverage(data.averageMood);
      data.gradientColors = _getMoodGradientForAverage(data.averageMood);
    }

    _moodCache = newCache;
  }

  Color _getMoodColorForAverage(double avgMood) {
    return getMoodColorInterpolated(avgMood, widget.themeService.getMoodGradient())
        .withValues(alpha: 0.35);
  }

  List<Color> _getMoodGradientForAverage(double avgMood) {
    final baseColor =
    getMoodColorInterpolated(avgMood, widget.themeService.getMoodGradient());
    // Create a gradient from darker to lighter version
    return [
      Color.lerp(baseColor, Colors.black, 0.2)!,
      baseColor,
    ];
  }

  _DayMoodData? _getMoodDataForDate(DateTime date) {
    final key = '${date.year}-${date.month}-${date.day}';
    return _moodCache[key];
  }

  void _navigateToDiary(DateTime date) {
    // Call the callback to notify parent to switch tabs and load date
    if (widget.onDateSelected != null) {
      widget.onDateSelected!(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, theme),

            // Static day header
            _buildDayHeader(theme),

            // Scrollable calendar months
            Expanded(
              child: _displayMode == DisplayMode.condensed
                  ? _buildCondensedYearView(theme)
                  : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 80,
                ),
                itemCount: 12,
                cacheExtent: 3000,
                addAutomaticKeepAlives: false,
                addRepaintBoundaries: true,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _MonthSection(
                    key: ValueKey('month_${_monthsData[index].month}'),
                    monthData: _monthsData[index],
                    getMoodData: _getMoodDataForDate,
                    theme: theme,
                    displayMode: _displayMode,
                    colorStyle: _colorStyle,
                    onDateTap: _navigateToDiary,
                  );
                },
              ),
            ),

            // Mode selector at bottom
            _buildModeSelector(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
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
          HamburgerMenuButton(controller: widget.drawerController),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mood Calendar',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your year at a glance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(ThemeData theme) {
    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days.map((day) {
          return Expanded(
            child: Center(
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCondensedYearView(ThemeData theme) {
    // Count entries per day and calculate average mood for the entire year
    final Map<DateTime, List<MoodEntry>> dailyEntries = {};
    for (var entry in widget.moodService.entries) {
      final date = DateTime(
        entry.timestamp.year,
        entry.timestamp.month,
        entry.timestamp.day,
      );
      if (date.year == currentYear) {
        dailyEntries.putIfAbsent(date, () => []);
        dailyEntries[date]!.add(entry);
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
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
                Text(
                  'Year at a Glance',
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
                ..._monthsData.map((monthData) {
                  return Expanded(
                    child: Center(
                      child: Text(
                        monthData.monthName.substring(0, 1),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
                        dayNumber.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    // Cells for each month
                    ..._monthsData.map((monthData) {
                      // Check if this day exists in this month
                      if (dayNumber > monthData.days.length) {
                        return const Expanded(child: SizedBox(height: 16));
                      }

                      final date = DateTime(currentYear, monthData.month, dayNumber);
                      final entries = dailyEntries[date] ?? [];
                      final today = DateTime.now();
                      final isToday = date.year == today.year &&
                          date.month == today.month &&
                          date.day == today.day;

                      // Calculate average mood for this day
                      Color cellColor;
                      Color? borderColor;

                      if (entries.isEmpty) {
                        cellColor = Colors.transparent;
                        borderColor = theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                            : const Color(0xFFE0E0E0);
                      } else {
                        // Calculate average mood rating for the day
                        final sum = entries.fold<int>(0, (sum, e) => sum + e.moodRating);
                        final avgMood = sum / entries.length;

                        // Use the actual mood rating color (same as used in calendar cells)
                        cellColor = _getMoodColorForAverage(avgMood);
                      }

                      return Expanded(
                        child: GestureDetector(
                          onTap: entries.isNotEmpty ? () => _navigateToDiary(date) : null,
                          child: Container(
                            height: 16,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              color: cellColor,
                              borderRadius: BorderRadius.circular(2),
                              border: isToday
                                  ? Border.all(
                                color: theme.colorScheme.primary,
                                width: 2,
                              )
                                  : (borderColor != null
                                  ? Border.all(color: borderColor, width: 1)
                                  : null),
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            // Legend with actual mood colors from gradient
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // No data indicator
                Text(
                  'No Data',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                _buildLegendBox(
                  Colors.transparent,
                  theme.brightness == Brightness.dark
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
                      : const Color(0xFFE0E0E0),
                ),
                const SizedBox(width: 16), // Space between no data and mood range

                // Mood range
                Text(
                  'Low',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(width: 6),
                _buildLegendBox(widget.themeService
                    .getMoodGradient()[0]
                    .withValues(alpha: 0.35)), // Rating 1-2
                _buildLegendBox(widget.themeService
                    .getMoodGradient()[2]
                    .withValues(alpha: 0.35)), // Rating 5-6
                _buildLegendBox(widget.themeService
                    .getMoodGradient()[4]
                    .withValues(alpha: 0.35)), // Rating 9-10
                const SizedBox(width: 6),
                Text(
                  'High',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendBox(Color color, [Color? borderColor]) {
    return Container(
      width: 12,
      height: 12,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2),
        border: borderColor != null ? Border.all(color: borderColor, width: 1) : null,
      ),
    );
  }

  Widget _buildModeSelector(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Compact header - always visible
          InkWell(
            onTap: () {
              setState(() {
                _isModePickerExpanded = !_isModePickerExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'View Options',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_getDisplayModeLabel(_displayMode)} • ${_getColorStyleLabel(_colorStyle)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isModePickerExpanded
                        ? Icons.expand_more_rounded
                        : Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: _isModePickerExpanded
                ? Column(
              children: [
                Divider(
                  height: 1,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Layout Mode Row
                      Row(
                        children: [
                          Icon(
                            Icons.view_module_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Layout',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildModeButton(
                            theme,
                            'Grid',
                            Icons.grid_4x4_rounded,
                            DisplayMode.normal,
                          ),
                          _buildModeButton(
                            theme,
                            'Circle',
                            Icons.circle_outlined,
                            DisplayMode.circle,
                          ),
                          _buildModeButton(
                            theme,
                            'Condensed',
                            Icons.calendar_view_month_rounded,
                            DisplayMode.condensed,
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Divider(
                        height: 1,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),

                      // Color Style Row
                      Row(
                        children: [
                          Icon(
                            Icons.palette_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Colors',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildColorStyleButton(
                            theme,
                            'Solid',
                            Icons.square_rounded,
                            ColorStyle.solid,
                          ),
                          _buildColorStyleButton(
                            theme,
                            'Gradient',
                            Icons.gradient_rounded,
                            ColorStyle.gradient,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  String _getDisplayModeLabel(DisplayMode mode) {
    switch (mode) {
      case DisplayMode.normal:
        return 'Grid';
      case DisplayMode.circle:
        return 'Circle';
      case DisplayMode.condensed:
        return 'Condensed';
    }
  }

  String _getColorStyleLabel(ColorStyle style) {
    switch (style) {
      case ColorStyle.solid:
        return 'Solid';
      case ColorStyle.gradient:
        return 'Gradient';
    }
  }

  Widget _buildModeButton(
      ThemeData theme,
      String label,
      IconData icon,
      DisplayMode mode,
      ) {
    final isSelected = _displayMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _displayMode = mode;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorStyleButton(
      ThemeData theme,
      String label,
      IconData icon,
      ColorStyle style,
      ) {
    final isSelected = _colorStyle == style;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _colorStyle = style;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.1)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Month data container
class _MonthData {
  final int month;
  final int year;
  final List<DateTime> days;
  final int startingWeekday;
  final String monthName;

  _MonthData({
    required this.month,
    required this.year,
    required this.days,
    required this.startingWeekday,
    required this.monthName,
  });
}

// Day mood data container
class _DayMoodData {
  final DateTime date;
  final List<MoodEntry> entries;
  double averageMood = 0;
  String emoji = '';
  Color solidColor = Colors.transparent;
  List<Color> gradientColors = [];

  _DayMoodData({
    required this.date,
    required this.entries,
  });
}

// Month section widget
class _MonthSection extends StatelessWidget {
  final _MonthData monthData;
  final _DayMoodData? Function(DateTime) getMoodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final ColorStyle colorStyle;
  final Function(DateTime) onDateTap;

  const _MonthSection({
    super.key,
    required this.monthData,
    required this.getMoodData,
    required this.theme,
    required this.displayMode,
    required this.colorStyle,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month name
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            monthData.monthName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),

        // Calendar grid
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: _CalendarGrid(
            monthData: monthData,
            getMoodData: getMoodData,
            theme: theme,
            displayMode: displayMode,
            colorStyle: colorStyle,
            onDateTap: onDateTap,
          ),
        ),
      ],
    );
  }
}

// Optimized calendar grid
class _CalendarGrid extends StatelessWidget {
  final _MonthData monthData;
  final _DayMoodData? Function(DateTime) getMoodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final ColorStyle colorStyle;
  final Function(DateTime) onDateTap;

  const _CalendarGrid({
    required this.monthData,
    required this.getMoodData,
    required this.theme,
    required this.displayMode,
    required this.colorStyle,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    int dayIndex = 0;

    final totalDays = monthData.startingWeekday + monthData.days.length;
    final totalWeeks = (totalDays / 7).ceil();

    final today = DateTime.now();

    for (int week = 0; week < totalWeeks; week++) {
      final weekCells = <Widget>[];

      for (int weekday = 0; weekday < 7; weekday++) {
        final cellIndex = week * 7 + weekday;

        if (cellIndex < monthData.startingWeekday) {
          weekCells.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox.shrink(),
              ),
            ),
          );
        } else if (dayIndex < monthData.days.length) {
          final date = monthData.days[dayIndex];
          final isToday = date.year == today.year &&
              date.month == today.month &&
              date.day == today.day;

          weekCells.add(
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: _DayCell(
                  date: date,
                  isToday: isToday,
                  moodData: getMoodData(date),
                  theme: theme,
                  displayMode: displayMode,
                  colorStyle: colorStyle,
                  onTap: onDateTap,
                ),
              ),
            ),
          );
          dayIndex++;
        } else {
          weekCells.add(
            const Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: SizedBox.shrink(),
              ),
            ),
          );
        }
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: weekCells),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: rows,
    );
  }
}

// Highly optimized day cell with tap functionality
class _DayCell extends StatelessWidget {
  final DateTime date;
  final bool isToday;
  final _DayMoodData? moodData;
  final ThemeData theme;
  final DisplayMode displayMode;
  final ColorStyle colorStyle;
  final Function(DateTime) onTap;

  const _DayCell({
    required this.date,
    required this.isToday,
    required this.moodData,
    required this.theme,
    required this.displayMode,
    required this.colorStyle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasEntry = moodData != null;

    return GestureDetector(
      onTap: hasEntry ? () => onTap(date) : null,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: displayMode == DisplayMode.circle
            ? _buildCircleMode(hasEntry)
            : displayMode == DisplayMode.normal
            ? (colorStyle == ColorStyle.gradient
            ? _buildGradientMode(hasEntry)
            : _buildSolidMode(hasEntry))
            : _buildSolidMode(hasEntry), // Fallback
      ),
    );
  }

  Widget _buildSolidMode(bool hasEntry) {
    final isDark = theme.brightness == Brightness.dark;
    final moodColor = hasEntry
        ? moodData!.solidColor
        : (isDark ? theme.colorScheme.surface : const Color(0xFFF5F5F5));
    final moodEmoji = hasEntry ? moodData!.emoji : '';
    final textColor = hasEntry
        ? (isDark ? Colors.white : Colors.grey[800]!)
        : (isDark ? Colors.white70 : Colors.grey[700]!);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: moodColor,
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        )
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
          if (hasEntry) ...[
            const SizedBox(height: 2),
            Text(
              moodEmoji,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCircleMode(bool hasEntry) {
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = hasEntry
        ? moodData!.solidColor.withValues(alpha: 1.0)
        : (isDark
        ? theme.colorScheme.onSurface.withValues(alpha: 0.2)
        : const Color(0xFFE0E0E0));
    final textColor = hasEntry
        ? (isDark ? Colors.white : Colors.grey[800]!)
        : (isDark ? Colors.white70 : Colors.grey[700]!);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday ? theme.colorScheme.primary : borderColor,
          width: isToday ? 3 : 4,
        ),
        color: isToday
            ? theme.colorScheme.primary.withValues(alpha: 0.05)
            : Colors.transparent,
      ),
      child: Center(
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildGradientMode(bool hasEntry) {
    final isDark = theme.brightness == Brightness.dark;
    final gradientColors = hasEntry
        ? moodData!.gradientColors
        : (isDark
        ? [theme.colorScheme.surface, theme.colorScheme.surface]
        : const [Color(0xFFEEEEEE), Color(0xFFE0E0E0)]);
    final moodEmoji = hasEntry ? moodData!.emoji : '';
    final textColor = hasEntry
        ? Colors.white
        : (isDark ? Colors.white70 : Colors.grey[700]!);
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: isToday
            ? Border.all(
          color: theme.colorScheme.primary,
          width: 2,
        )
            : null,
        boxShadow: hasEntry
            ? [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
              color: textColor,
            ),
          ),
          if (hasEntry) ...[
            const SizedBox(height: 2),
            Text(
              moodEmoji,
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }
}